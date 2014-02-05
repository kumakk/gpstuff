function gpcf = gpcf_matern32(varargin)
%GPCF_MATERN32  Create a Matern nu=3/2 covariance function
%
%  Description
%    GPCF = GPCF_MATERN32('PARAM1',VALUE1,'PARAM2,VALUE2,...) 
%    creates Matern nu=3/2 covariance function structure in which
%    the named parameters have the specified values. Any
%    unspecified parameters are set to default values.
%
%    GPCF = GPCF_MATERN32(GPCF,'PARAM1',VALUE1,'PARAM2,VALUE2,...) 
%    modify a covariance function structure with the named
%    parameters altered with the specified values.
%  
%    Parameters for Matern nu=3/2 covariance function [default]
%      magnSigma2        - magnitude (squared) [0.1]
%      lengthScale       - length scale for each input. [1]
%                          This can be either scalar corresponding
%                          to an isotropic function or vector
%                          defining own length-scale for each input
%                          direction.
%      magnSigma2_prior  - prior for magnSigma2  [prior_logunif]
%      lengthScale_prior - prior for lengthScale [prior_t]
%      metric            - metric structure used by the covariance function []
%      selectedVariables - vector defining which inputs are used [all]
%                          selectedVariables is shorthand for using
%                          metric_euclidean with corresponding components
%
%    Note! If the prior is 'prior_fixed' then the parameter in
%    question is considered fixed and it is not handled in
%    optimization, grid integration, MCMC etc.
%
%  See also
%    GP_SET, GPCF_*, PRIOR_*, METRIC_*

% Copyright (c) 2007-2010 Jarno Vanhatalo
% Copyright (c) 2010 Aki Vehtari

% This software is distributed under the GNU General Public
% License (version 3 or later); please refer to the file
% License.txt, included with the software, for details.

  if nargin>0 && ischar(varargin{1}) && ismember(varargin{1},{'init' 'set'})
    % remove init and set
    varargin(1)=[];
  end
  
  ip=inputParser;
  ip.FunctionName = 'GPCF_MATERN32';
  ip.addOptional('gpcf', [], @isstruct);
  ip.addParamValue('magnSigma2',0.1, @(x) isscalar(x) && x>0);
  ip.addParamValue('lengthScale',1, @(x) isvector(x) && all(x>0));
  ip.addParamValue('metric',[], @isstruct);
  ip.addParamValue('magnSigma2_prior', prior_logunif(), ...
                   @(x) isstruct(x) || isempty(x));
  ip.addParamValue('lengthScale_prior',prior_t(), ...
                   @(x) isstruct(x) || isempty(x));
  ip.addParamValue('selectedVariables',[], @(x) isempty(x) || ...
                   (isvector(x) && all(x>0)));
  ip.parse(varargin{:});
  gpcf=ip.Results.gpcf;
  
  if isempty(gpcf)
    init=true;
    gpcf.type = 'gpcf_matern32';
  else
    if ~isfield(gpcf,'type') && ~isequal(gpcf.type,'gpcf_matern32')
      error('First argument does not seem to be a valid covariance function structure')
    end
    init=false;
  end
  if init
    % Set the function handles to the subfunctions
    gpcf.fh.pak = @gpcf_matern32_pak;
    gpcf.fh.unpak = @gpcf_matern32_unpak;
    gpcf.fh.lp = @gpcf_matern32_lp;
    gpcf.fh.lpg = @gpcf_matern32_lpg;
    gpcf.fh.cfg = @gpcf_matern32_cfg;
    gpcf.fh.ginput = @gpcf_matern32_ginput;
    gpcf.fh.cov = @gpcf_matern32_cov;
    gpcf.fh.trcov = @gpcf_matern32_trcov;
    gpcf.fh.trvar = @gpcf_matern32_trvar;
    gpcf.fh.recappend = @gpcf_matern32_recappend;
    gpcf.fh.cf2ss = @gpcf_matern32_cf2ss;
  end
  
  % Initialize parameters
  if init || ~ismember('lengthScale',ip.UsingDefaults)
    gpcf.lengthScale = ip.Results.lengthScale;
  end
  if init || ~ismember('magnSigma2',ip.UsingDefaults)
    gpcf.magnSigma2 = ip.Results.magnSigma2;
  end

  % Initialize prior structure
  if init
    gpcf.p=[];
  end
  if init || ~ismember('lengthScale_prior',ip.UsingDefaults)
    gpcf.p.lengthScale=ip.Results.lengthScale_prior;
  end
  if init || ~ismember('magnSigma2_prior',ip.UsingDefaults)
    gpcf.p.magnSigma2=ip.Results.magnSigma2_prior;
  end

  %Initialize metric
  if ~ismember('metric',ip.UsingDefaults)
    if ~isempty(ip.Results.metric)
      gpcf.metric = ip.Results.metric;
      gpcf = rmfield(gpcf, 'lengthScale');
      gpcf.p = rmfield(gpcf.p, 'lengthScale');
    elseif isfield(gpcf,'metric')
      if ~isfield(gpcf,'lengthScale')
        gpcf.lengthScale = gpcf.metric.lengthScale;
      end
      if ~isfield(gpcf.p,'lengthScale')
        gpcf.p.lengthScale = gpcf.metric.p.lengthScale;
      end
      gpcf = rmfield(gpcf, 'metric');
    end
  end
  
  % selectedVariables options implemented using metric_euclidean
  if ~ismember('selectedVariables',ip.UsingDefaults)
    if ~isfield(gpcf,'metric')
      if ~isempty(ip.Results.selectedVariables)
        gpcf.selectedVariables = ip.Results.selectedVariables;
%         gpcf.metric=metric_euclidean('components',...
%                                      num2cell(ip.Results.selectedVariables),...
%                                      'lengthScale',gpcf.lengthScale,...
%                                      'lengthScale_prior',gpcf.p.lengthScale);
%         gpcf = rmfield(gpcf, 'lengthScale');
%         gpcf.p = rmfield(gpcf.p, 'lengthScale');
      end
    elseif isfield(gpcf,'metric') 
      if ~isempty(ip.Results.selectedVariables)
        gpcf.metric=metric_euclidean(gpcf.metric,...
                                     'components',...
                                     num2cell(ip.Results.selectedVariables));
        if ~ismember('lengthScale',ip.UsingDefaults)
          gpcf.metric.lengthScale=ip.Results.lengthScale;
          gpcf = rmfield(gpcf, 'lengthScale');
        end
        if ~ismember('lengthScale_prior',ip.UsingDefaults)
          gpcf.metric.p.lengthScale=ip.Results.lengthScale_prior;
          gpcf.p = rmfield(gpcf.p, 'lengthScale');
        end
      else
        if ~isfield(gpcf,'lengthScale')
          gpcf.lengthScale = gpcf.metric.lengthScale;
        end
        if ~isfield(gpcf.p,'lengthScale')
          gpcf.p.lengthScale = gpcf.metric.p.lengthScale;
        end
        gpcf = rmfield(gpcf, 'metric');
      end
    end
  end

end

function [w,s] = gpcf_matern32_pak(gpcf, w)
%GPCF_MATERN32_PAK  Combine GP covariance function hyper-parameters
%                   into one vector.
%
%  Description
%    W = GPCF_MATERN32_PAK(GPCF) takes a covariance function
%    structure GPCF and combines the covariance function
%    parameters and their hyperparameters into a single row
%    vector W. This is a mandatory subfunction used for example 
%    in energy and gradient computations.
%
%       w = [ log(gpcf.magnSigma2)
%             (hyperparameters of gpcf.magnSigma2) 
%             log(gpcf.lengthScale(:))
%             (hyperparameters of gpcf.lengthScale)]'
%
%  See also
%    GPCF_MATERN32_UNPAK

  w = []; s = {};
  
  if ~isempty(gpcf.p.magnSigma2)
    w = [w log(gpcf.magnSigma2)];
    s = [s; 'log(matern32.magnSigma2)'];
    % Hyperparameters of magnSigma2
    [wh sh] = gpcf.p.magnSigma2.fh.pak(gpcf.p.magnSigma2);
    w = [w wh];
    s = [s; sh];
  end        
  
  if isfield(gpcf,'metric')
    [wm sm] = gpcf.metric.fh.pak(gpcf.metric);
    w = [w wm];
    s = [s; sm];
  else
    if ~isempty(gpcf.p.lengthScale)
      w = [w log(gpcf.lengthScale)];
      if numel(gpcf.lengthScale)>1
        s = [s; sprintf('log(matern32.lengthScale x %d)',numel(gpcf.lengthScale))];
      else
        s = [s; 'log(matern32.lengthScale)'];
      end
      % Hyperparameters of lengthScale
      [wh sh] = gpcf.p.lengthScale.fh.pak(gpcf.p.lengthScale);
      w = [w wh];
      s = [s; sh];
    end
  end
  
end

function [gpcf, w] = gpcf_matern32_unpak(gpcf, w)
%GPCF_MATERN32_UNPAK  Sets the covariance function parameters
%                     into the structure
%
%  Description
%    [GPCF, W] = GPCF_MATERN32_UNPAK(GPCF, W) takes a covariance
%    function structure GPCF and a hyper-parameter vector W,
%    and returns a covariance function structure identical to
%    the input, except that the covariance hyper-parameters have
%    been set to the values in W. Deletes the values set to GPCF
%    from W and returns the modified W. This is a mandatory 
%    subfunction used for example in energy and gradient computations.
%
%    Assignment is inverse of  
%       w = [ log(gpcf.magnSigma2)
%             (hyperparameters of gpcf.magnSigma2)
%             log(gpcf.lengthScale(:))
%             (hyperparameters of gpcf.lengthScale)]'
%
%  See also
%    GPCF_MATERN32_PAK
  
  gpp=gpcf.p;
  if ~isempty(gpp.magnSigma2)
    gpcf.magnSigma2 = exp(w(1));
    w = w(2:end);
    % Hyperparameters of magnSigma2
    [p, w] = gpcf.p.magnSigma2.fh.unpak(gpcf.p.magnSigma2, w);
    gpcf.p.magnSigma2 = p;
  end
  
  if isfield(gpcf,'metric')
    [metric, w] = gpcf.metric.fh.unpak(gpcf.metric, w);
    gpcf.metric = metric;
  else            
    if ~isempty(gpp.lengthScale)
      i1=1;
      i2=length(gpcf.lengthScale);
      gpcf.lengthScale = exp(w(i1:i2));
      w = w(i2+1:end);
      % Hyperparameters of lengthScale
      [p, w] = gpcf.p.lengthScale.fh.unpak(gpcf.p.lengthScale, w);
      gpcf.p.lengthScale = p;
    end
  end
  
end

function lp = gpcf_matern32_lp(gpcf)
%GPCF_MATERN32_LP  Evaluate the log prior of covariance function parameters
%
%  Description
%    LP = GPCF_MATERN32_LP(GPCF, X, T) takes a covariance function
%    structure GPCF together with a matrix X of input
%    vectors and a vector T of target vectors and evaluates log
%    p(th) x J, where th is a vector of MATERN32 parameters and J
%    is the Jacobian of transformation exp(w) = th. (Note that
%    the parameters are log transformed, when packed.) This is 
%    a mandatory subfunction used for example in energy computations.
%
%  See also
%    GPCF_MATERN32_PAK, GPCF_MATERN32_UNPAK, GPCF_MATERN32_LPG, GP_E
%

% Evaluate the prior contribution to the error. The parameters that
% are sampled are transformed, e.g., W = log(w) where w is all
% the "real" samples. On the other hand errors are evaluated in
% the W-space so we need take into account also the Jacobian of
% transformation, e.g., W -> w = exp(W). See Gelman et.al., 2004,
% Bayesian data Analysis, second edition, p24.
  lp = 0;
  gpp=gpcf.p;
  
  if ~isempty(gpcf.p.magnSigma2)
    lp = lp +gpp.magnSigma2.fh.lp(gpcf.magnSigma2, ...
                   gpp.magnSigma2) +log(gpcf.magnSigma2);
  end
  
  if isfield(gpcf,'metric')            
    lp = lp +gpcf.metric.fh.lp(gpcf.metric);
  elseif ~isempty(gpp.lengthScale)
    lp = lp +gpp.lengthScale.fh.lp(gpcf.lengthScale, ...
                   gpp.lengthScale) +sum(log(gpcf.lengthScale));
  end
end

function lpg = gpcf_matern32_lpg(gpcf)
%GPCF_MATERN32_LPG  Evaluate gradient of the log prior with respect
%                   to the parameters.
%
%  Description
%    LPG = GPCF_MATERN32_LPG(GPCF) takes a covariance function
%    structure GPCF and returns LPG = d log (p(th))/dth, where th
%    is the vector of parameters. This is a mandatory subfunction 
%    used for example in gradient computations.
%
%  See also
%    GPCF_MATERN32_PAK, GPCF_MATERN32_UNPAK, GPCF_MATERN32_LP, GP_G

  lpg = [];
  gpp=gpcf.p;
  
  if ~isempty(gpcf.p.magnSigma2)            
    lpgs = gpp.magnSigma2.fh.lpg(gpcf.magnSigma2, gpp.magnSigma2);
    lpg = [lpg lpgs(1).*gpcf.magnSigma2+1 lpgs(2:end)];
  end
  
  if isfield(gpcf,'metric')
    lpg_dist = gpcf.metric.fh.lpg(gpcf.metric);
    lpg=[lpg lpg_dist];
  else
    if ~isempty(gpcf.p.lengthScale)
      lll = length(gpcf.lengthScale);
      lpgs = gpp.lengthScale.fh.lpg(gpcf.lengthScale, gpp.lengthScale);
      lpg = [lpg lpgs(1:lll).*gpcf.lengthScale+1 lpgs(lll+1:end)];
    end
  end
end

function DKff = gpcf_matern32_cfg(gpcf, x, x2, mask,i1)
%GPCF_MATERN32_CFG  Evaluate gradient of covariance function 
%                      hyper-prior with respect to the parameters.
%
%  Description
%    DKff = GPCF_MATERN32_CFG(GPCF, X) takes a
%    covariance function structure GPCF, a matrix X of input
%    vectors and returns DKff, the gradients of covariance matrix
%    Kff = k(X,X) with respect to th (cell array with matrix
%    elements). This is a mandatory subfunction used for example 
%    in gradient computations.
%
%    DKff = GPCF_MATERN32_CFG(GPCF, X, X2) takes a
%    covariance function structure GPCF, a matrix X of input
%    vectors and returns DKff, the gradients of covariance matrix
%    Kff = k(X,X2) with respect to th (cell array with matrix
%    elements). This subfunction is needed when using sparse 
%    approximations (e.g. FIC).
%
%    DKff = GPCF_MATERN32_CFG(GPCF, X, [], MASK)
%    takes a covariance function structure GPCF, a matrix X
%    of input vectors and returns DKff, the diagonal of gradients
%    of covariance matrix Kff = k(X,X2) with respect to th (cell
%    array with matrix elements). This subfunction is needed when 
%    using sparse approximations (e.g. FIC).
%
%    DKff = GPCF_MATERN32_CFG(GPCF, X, X2, [], i) takes a
%    covariance function structure GPCF, a matrix X of input
%    vectors and returns DKff, the gradient of covariance matrix
%    Kff = k(X,X2) with respect to ith hyperparameter (matrix). 
%    5th input can also be used without X2. This subfunction is
%    needed when using memory save option in gp_set.
%
%  See also
%    GPCF_MATERN32_PAK, GPCF_MATERN32_UNPAK, GPCF_MATERN32_LP, GP_G

  gpp=gpcf.p;

  i2=1;
  DKff = {};
  gprior = [];

  if nargin==5
    % Use memory save option
    savememory=1;
    if i1==0
      % Return number of hyperparameters
      if ~isempty(gpcf.p.magnSigma2)
        i=1;
      end
      if ~isempty(gpcf.p.lengthScale)
        i=i+length(gpcf.lengthScale);
      end
      DKff=i;
      return
    end
  else
    savememory=0;
  end
  
  % Evaluate: DKff{1} = d Kff / d magnSigma2
  %           DKff{2} = d Kff / d lengthScale
  % NOTE! Here we have already taken into account that the parameters
  % are transformed through log() and thus dK/dlog(p) = p * dK/dp
  % evaluate the gradient for training covariance
  if nargin == 2 || (isempty(x2) && isempty(mask))
    Cdm = gpcf_matern32_trcov(gpcf, x);

    ii1=0;
    if ~isempty(gpcf.p.magnSigma2)
      ii1 = ii1 +1;
      DKff{ii1} = Cdm;
    end
    
    if isfield(gpcf,'metric')
      dist = gpcf.metric.fh.dist(gpcf.metric, x);
      distg = gpcf.metric.fh.distg(gpcf.metric, x);
      gprior_dist = gpcf.metric.fh.lpg(gpcf.metric);
      for i=1:length(distg)
        ii1 = ii1+1;
        DKff{ii1} = -gpcf.magnSigma2.*3.*dist.*distg{i}.*exp(-sqrt(3).*dist);
      end
    else
      if isfield(gpcf,'selectedVariables')
        x = x(:,gpcf.selectedVariables);
      end
      [n, m] =size(x);
      if savememory
        if i1==1
          DKff=DKff{ii1};
          return
        else
          ii1=ii1-1;
          i1=i1-1;
        end
      else
        i1=1:m;
      end
      if ~isempty(gpcf.p.lengthScale)
        ma2 = gpcf.magnSigma2;
        % loop over all the lengthScales
        if length(gpcf.lengthScale) == 1
          % In the case of isotropic MATERN32
          s = 1./gpcf.lengthScale;
          dist = 0;
          for i=1:m
            D = bsxfun(@minus,x(:,i),x(:,i)');
            dist = dist + D.^2;
          end
          D = ma2.*3.*dist.*s.^2.*exp(-sqrt(3.*dist).*s);
          ii1 = ii1+1;
          DKff{ii1} = D;                    
        else
          % In the case ARD is used
          s = 1./gpcf.lengthScale.^2;
          dist = 0;
          for i=1:m
            dist = dist + s(i).*(bsxfun(@minus,x(:,i),x(:,i)')).^2;
          end
          dist=sqrt(dist);
          for i=i1
            D = 3.*ma2.*s(i).*(bsxfun(@minus,x(:,i),x(:,i)')).^2.*exp(-sqrt(3).*dist);
            ii1 = ii1+1;
            DKff{ii1} = D;
          end
        end
      end
    end
    % Evaluate the gradient of non-symmetric covariance (e.g. K_fu)
  elseif nargin == 3 || isempty(mask)
    if size(x,2) ~= size(x2,2)
      error('gpcf_matern32 -> _ghyper: The number of columns in x and x2 has to be the same. ')
    end

    ii1=0;
    K = gpcf.fh.cov(gpcf, x, x2);
    if ~isempty(gpcf.p.magnSigma2)
      ii1 = ii1 +1;
      DKff{ii1} = K;
    end
    
    if isfield(gpcf,'metric')                
      dist = gpcf.metric.fh.dist(gpcf.metric, x, x2);
      distg = gpcf.metric.fh.distg(gpcf.metric, x, x2);
      gprior_dist = gpcf.metric.fh.lpg(gpcf.metric);
      for i=1:length(distg)
        ii1 = ii1+1;
        DKff{ii1} = -gpcf.magnSigma2.*3.*dist.*distg{i}.*exp(-sqrt(3).*dist);
      end
    else
      if isfield(gpcf,'selectedVariables')
        x = x(:,gpcf.selectedVariables);
        x2 = x2(:,gpcf.selectedVariables);
      end
      [n, m] =size(x);
      if savememory
        if i1==1
          DKff=DKff{ii1};
          return
        else
          ii1=ii1-1;
          i1=i1-1;
        end
      else
        i1=1:m;
      end
      if ~isempty(gpcf.p.lengthScale)
        % Evaluate help matrix for calculations of derivatives with respect
        % to the lengthScale
        if length(gpcf.lengthScale) == 1
          % In the case of an isotropic matern32
          s = 1./gpcf.lengthScale;
          ma2 = gpcf.magnSigma2;
          dist = 0; 
          for i=1:m
            dist = dist + (bsxfun(@minus,x(:,i),x2(:,i)')).^2;
          end
          DK_l = 3.*ma2.*s.^2.*dist.*exp(-s.*sqrt(3.*dist));
          ii1=ii1+1;
          DKff{ii1} = DK_l;
        else
          % In the case ARD is used
          s = 1./gpcf.lengthScale.^2;
          ma2 = gpcf.magnSigma2;
          dist = 0;
          for i=1:m
            dist = dist + s(i).*(bsxfun(@minus,x(:,i),x2(:,i)')).^2;
          end
          for i=i1
            DK_l = 3.*ma2.*s(i).*(bsxfun(@minus,x(:,i),x2(:,i)')).^2.*exp(-sqrt(3.*dist));
            ii1=ii1+1;
            DKff{ii1} = DK_l;
          end
        end
      end
    end
    % Evaluate: DKff{1}    = d mask(Kff,I) / d magnSigma2
    %           DKff{2...} = d mask(Kff,I) / d lengthScale
  elseif nargin == 4 || nargin == 5
    ii1=0;
    
    if ~isempty(gpcf.p.magnSigma2) && (~savememory || all(i1==1))
      ii1 = ii1+1;
      DKff{ii1} = gpcf.fh.trvar(gpcf, x);   % d mask(Kff,I) / d magnSigma2
    end
    if isfield(gpcf,'metric')
      dist = 0;
      distg = gpcf.metric.fh.distg(gpcf.metric, x, [], 1);
      gprior_dist = gpcf.metric.fh.lpg(gpcf.metric);
      for i=1:length(distg)
        ii1 = ii1+1;
        DKff{ii1} = 0;
      end
    else
      if ~isempty(gpcf.p.lengthScale)
        for i2=1:length(gpcf.lengthScale)
          ii1 = ii1+1;
          DKff{ii1}  = 0; % d mask(Kff,I) / d lengthScale
        end
      end
    end
  end
  if savememory
    DKff=DKff{1};
  end
end

function DKff = gpcf_matern32_ginput(gpcf, x, x2, i1)
%GPCF_MATERN32_GINPUT  Evaluate gradient of covariance function with 
%                      respect to x.
%
%  Description
%    DKff = GPCF_MATERN32_GINPUT(GPCF, X) takes a covariance
%    function structure GPCF, a matrix X of input vectors
%    and returns DKff, the gradients of covariance matrix Kff =
%    k(X,X) with respect to X (cell array with matrix elements).
%    This subfunction is needed when computing gradients with 
%    respect to inducing inputs in sparse approximations.
%
%    DKff = GPCF_MATERN32_GINPUT(GPCF, X, X2) takes a covariance
%    function structure GPCF, a matrix X of input vectors
%    and returns DKff, the gradients of covariance matrix Kff =
%    k(X,X2) with respect to X (cell array with matrix elements).
%    This subfunction is needed when computing gradients with 
%    respect to inducing inputs in sparse approximations.
%
%    DKff = GPCF_MATERN32_GINPUT(GPCF, X, X2, i) takes a covariance
%    function structure GPCF, a matrix X of input vectors
%    and returns DKff, the gradients of covariance matrix Kff =
%    k(X,X2) with respect to ith covariate in X (matrix). This 
%    subfunction is needed when using memory save option in gp_set.
%
%  See also
%    GPCF_MATERN32_PAK, GPCF_MATERN32_UNPAK, GPCF_MATERN32_LP, GP_G

  [n, m] =size(x);
  ma2 = gpcf.magnSigma2;
  ii1 = 0;
  if nargin==4
    % Use memory save option
    savememory=1;
    if i1==0
      % Return number of covariates
      if isfield(gpcf,'selectedVariables')
        DKff=length(gpcf.selectedVariables);
      else
        DKff=m;
      end
      return
    end
  else
    savememory=0;
  end
    
  if nargin == 2 || isempty(x2)
    if isfield(gpcf,'metric')
      K = gpcf.fh.trcov(gpcf, x);
      dist = gpcf.metric.fh.dist(gpcf.metric, x);
      gdist = gpcf.metric.fh.ginput(gpcf.metric, x);
      for i=1:length(gdist)
        ii1 = ii1+1;
        DKff{ii1} = -K./(1+sqrt(3)*dist).*3.*dist.*gdist{ii1};
      end
    else
      if length(gpcf.lengthScale) == 1
        % In the case of an isotropic
        s = repmat(1./gpcf.lengthScale.^2, 1, m);
      else
        s = 1./gpcf.lengthScale.^2;
      end
      dist=0;
      for i2=1:m
        dist = dist + s(i2).*(bsxfun(@minus,x(:,i2),x(:,i2)')).^2;
      end
      if ~savememory
        i1=1:m;
      end
      for i=i1
        for j = 1:n
          D1 = zeros(n,n);
          D1(j,:) = (s(i)).*bsxfun(@minus,x(j,i),x(:,i)');
          D1 = D1 + D1';
          DK = -3.*ma2.*exp(-sqrt(3.*dist)).*D1;
          
          ii1 = ii1 + 1;
          DKff{ii1} = DK;
        end
      end
    end
  elseif nargin == 3 || nargin == 4
    if isfield(gpcf,'metric')
      K = gpcf.fh.cov(gpcf, x, x2);
      dist = gpcf.metric.fh.dist(gpcf.metric, x, x2);
      gdist = gpcf.metric.fh.ginput(gpcf.metric, x, x2);
      for i=1:length(gdist)
        ii1 = ii1+1;
        DKff{ii1} = -K./(1+sqrt(3)*dist).*3.*dist.*gdist{ii1};
      end
    else
      [n2, m2] =size(x2);
      if length(gpcf.lengthScale) == 1
        s = repmat(1./gpcf.lengthScale.^2, 1, m);
      else
        s = 1./gpcf.lengthScale.^2;
      end
      dist=0; 
      for i2=1:m
        dist = dist + s(i2).*(bsxfun(@minus,x(:,i2),x2(:,i2)')).^2;
      end
      if ~savememory
        i1=1:m;
      end
      ii1 = 0;
      for i=i1
        for j = 1:n
          D1 = zeros(n,n2);
          D1(j,:) = (s(i)).*bsxfun(@minus,x(j,i),x2(:,i)');
          DK = -3.*ma2.*exp(-sqrt(3.*dist)).*D1;
          ii1 = ii1 + 1;
          DKff{ii1} = DK;
        end
      end
    end
  end
end

function C = gpcf_matern32_cov(gpcf, x1, x2)
%GP_MATERN32_COV  Evaluate covariance matrix between two input vectors
%
%  Description
%    C = GP_MATERN32_COV(GP, TX, X) takes in covariance function
%    of a Gaussian process GP and two matrixes TX and X that
%    contain input vectors to GP. Returns covariance matrix C. 
%    Every element ij of C contains covariance between inputs i
%    in TX and j in X. This is a mandatory subfunction used for 
%    example in prediction and energy computations.
%
%
%  See also
%    GPCF_MATERN32_TRCOV, GPCF_MATERN32_TRVAR, GP_COV, GP_TRCOV
  
  if isempty(x2)
    x2=x1;
  end

  if size(x1,2)~=size(x2,2)
    error('the number of columns of X1 and X2 has to be same')
  end

  if isfield(gpcf,'metric')
    dist = gpcf.metric.fh.dist(gpcf.metric, x1, x2);
    dist(dist<eps) = 0;
    C = gpcf.magnSigma2.*(1+sqrt(3).*dist).*exp(-sqrt(3).*dist);
  else
    if isfield(gpcf,'selectedVariables')
      x1 = x1(:,gpcf.selectedVariables);
      x2 = x2(:,gpcf.selectedVariables);
    end
    [n1,m1]=size(x1);
    [n2,m2]=size(x2);
    C=zeros(n1,n2);
    ma2 = gpcf.magnSigma2;
    
    % Evaluate the covariance
    if ~isempty(gpcf.lengthScale)
      s2 = 1./gpcf.lengthScale.^2;
      % If ARD is not used make s a vector of
      % equal elements
      if size(s2)==1
        s2 = repmat(s2,1,m1);
      end
      dist=zeros(n1,n2);
      for j=1:m1
        dist = dist + s2(j).*(bsxfun(@minus,x1(:,j),x2(:,j)')).^2;
      end
      dist = sqrt(dist);
      C = ma2.*(1+sqrt(3).*dist).*exp(-sqrt(3).*dist);
    end
    C(C<eps)=0;
  end
end

function C = gpcf_matern32_trcov(gpcf, x)
%GP_MATERN32_TRCOV  Evaluate training covariance matrix of inputs
%
%  Description
%    C = GP_MATERN32_TRCOV(GP, TX) takes in covariance function
%    of a Gaussian process GP and matrix TX that contains
%    training input vectors. Returns covariance matrix C. Every
%    element ij of C contains covariance between inputs i and j
%    in TX. This is a mandatory subfunction used for example in
%    prediction and energy computations.
%
%  See also
%    GPCF_MATERN32_COV, GPCF_MATERN32_TRVAR, GP_COV, GP_TRCOV
  
  if isfield(gpcf,'metric')
    ma2 = gpcf.magnSigma2;
    dist = gpcf.metric.fh.dist(gpcf.metric, x);
    C = ma2.*(1+sqrt(3).*dist).*exp(-sqrt(3).*dist);
  else
    % Try to use the C-implementation            
    C = trcov(gpcf,x);
    if isnan(C)
      % If there wasn't C-implementation do here
      if isfield(gpcf, 'selectedVariables')
        x = x(:,gpcf.selectedVariables);
      end
      [n, m] =size(x);
      
      s2 = 1./(gpcf.lengthScale).^2;
      if size(s2)==1
        s2 = repmat(s2,1,m);
      end
      ma2 = gpcf.magnSigma2;
      
      % Here we take advantage of the
      % symmetry of covariance matrix
      C=zeros(n,n);
      for i1=2:n
        i1n=(i1-1)*n;
        for i2=1:i1-1
          ii=i1+(i2-1)*n;
          for i3=1:m
            C(ii)=C(ii)+s2(i3).*(x(i1,i3)-x(i2,i3)).^2;       % the covariance function
          end
          C(i1n+i2)=C(ii);
        end
      end
      dist = sqrt(C);
      C = ma2.*(1+sqrt(3).*dist).*exp(-sqrt(3).*dist);
      C(C<eps)=0;
    end
  end
end

function C = gpcf_matern32_trvar(gpcf, x)
%GP_MATERN32_TRVAR  Evaluate training variance vector
%
%  Description
%    C = GP_MATERN32_TRVAR(GPCF, TX) takes in covariance function
%    of a Gaussian process GPCF and matrix TX that contains
%    training inputs. Returns variance vector C. Every element i
%    of C contains variance of input i in TX. This is a mandatory 
%    subfunction used for example in prediction and energy computations.
%
%
%  See also
%    GPCF_MATERN32_COV, GP_COV, GP_TRCOV        
  [n, m] =size(x);

  C = ones(n,1).*gpcf.magnSigma2;
  C(C<eps)=0;
end

function reccf = gpcf_matern32_recappend(reccf, ri, gpcf)
%RECAPPEND  Record append
%
%  Description
%    RECCF = GPCF_MATERN32_RECAPPEND(RECCF, RI, GPCF) takes a
%    covariance function record structure RECCF, record index RI
%    and covariance function structure GPCF with the current MCMC
%    samples of the parameters. Returns RECCF which contains
%    all the old samples and the current samples from GPCF.
%    This subfunction is needed when using MCMC sampling (gp_mc).
%
%  See also
%    GP_MC and GP_MC -> RECAPPEND

  if nargin == 2
    % Initialize the record
    reccf.type = 'gpcf_matern32';

    % Initialize parameters
    reccf.lengthScale= [];
    reccf.magnSigma2 = [];

    % Set the function handles
    reccf.fh.pak = @gpcf_matern32_pak;
    reccf.fh.unpak = @gpcf_matern32_unpak;
    reccf.fh.e = @gpcf_matern32_lp;
    reccf.fh.lpg = @gpcf_matern32_lpg;
    reccf.fh.cfg = @gpcf_matern32_cfg;
    reccf.fh.cov = @gpcf_matern32_cov;
    reccf.fh.trcov  = @gpcf_matern32_trcov;
    reccf.fh.trvar  = @gpcf_matern32_trvar;
    reccf.fh.recappend = @gpcf_matern32_recappend;
    reccf.p=[];
    reccf.p.lengthScale=[];
    reccf.p.magnSigma2=[];
    if isfield(ri.p,'lengthScale') && ~isempty(ri.p.lengthScale)
      reccf.p.lengthScale = ri.p.lengthScale;
    end
    if ~isempty(ri.p.magnSigma2)
      reccf.p.magnSigma2 = ri.p.magnSigma2;
    end
    if isfield(ri, 'selectedVariables')
        reccf.selectedVariables = ri.selectedVariables;
    end
  else
    % Append to the record
    gpp = gpcf.p;

    if ~isfield(gpcf,'metric')
      % record lengthScale
      reccf.lengthScale(ri,:)=gpcf.lengthScale;
      if isfield(gpp,'lengthScale') && ~isempty(gpp.lengthScale)
        reccf.p.lengthScale = gpp.lengthScale.fh.recappend(reccf.p.lengthScale, ri, gpcf.p.lengthScale);
      end
    end
    % record magnSigma2
    reccf.magnSigma2(ri,:)=gpcf.magnSigma2;
    if isfield(gpp,'magnSigma2') && ~isempty(gpp.magnSigma2)
      reccf.p.magnSigma2 = gpp.magnSigma2.fh.recappend(reccf.p.magnSigma2, ri, gpcf.p.magnSigma2);
    end
  end
end

function [F,L,Qc,H,Pinf,dF,dQc,dPinf,params,nhp] = gpcf_matern32_cf2ss(gpcf)
%GPCF_MATERN_CF2SS Convert the covariance function to state space form
%
%  Description
%    Convert the covariance function to state space form such that
%    the process can be described by the stochastic differential equation
%    of the form: 
%      df(t)/dt = F f(t) + L w(t),
%    where w(t) is a white noise process. The observation model now 
%    corresponds to y_k = H f(t_k) + r_k, where r_k ~ N(0,sigma2).

  % Return model matrices and derivatives and parameter information
  [F,L,Qc,H,Pinf,dF0,dQc0,dPinf0,params] = ...
      cf_matern32_to_ss(gpcf.magnSigma2, gpcf.lengthScale);
  
  % Parameternames in right order
  pm = {'magnSigma2','lengthScale'};
  
  % Number of hyperparameters of hyperparameters
  nhp = [];
  
  % Calculate these gradients
  for k = 1:length(pm)
      if isempty(gpcf.p.(pm{k})), 
          ind(k) = false; 
      else
          ind(k) = true; 
          nhp = [nhp,length(gpcf.p.(pm{k}).fh.pak(gpcf.p.(pm{k})))];
      end
  end
  
  % Use only optimized parameter gradients
  dF0    = dF0(:,:,ind);
  dQc0   = dQc0(:,:,ind);
  dPinf0 = dPinf0(:,:,ind);
  
  % Add zeros for hyperparameters of hyperparamaters
  dF=zeros([size(F),0]); dQc=zeros([size(Qc),0]); dPinf=zeros([size(Pinf),0]);
  for k = 1:length(nhp)
         dF(:,:,end+1) = dF0(:,:,k);
         dQc(:,:,end+1) = dQc0(:,:,k);
         dPinf(:,:,end+1) = dPinf0(:,:,k);
         dF(:,:,end+1:end+nhp(k)) = zeros([size(F),nhp(k)]);
         dQc(:,:,end+1:end+nhp(k)) = zeros([size(Qc),nhp(k)]);
         dPinf(:,:,end+1:end+nhp(k)) = zeros([size(Pinf),nhp(k)]);
  end
end

