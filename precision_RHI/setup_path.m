function setup_path()
%SETUP_PATH  Put this repository's code and tests on the MATLAB/Octave path.
%
%   Run this once per session from the repository root:
%       setup_path
%       run_all_figures          % reproduce every figure of the paper
%       run_all_checks           % verify the gradients, numbers and figures
%
%   Nothing is added permanently; call SAVEPATH yourself if you want that.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'code'));
addpath(fullfile(here, 'tests'));
fprintf('precision_RHI on the path (%s)\n', here);
end
