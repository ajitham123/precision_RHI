function rhi_seed(s)
%RHI_SEED  Reset the random number generator (portable across MATLAB/Octave).
%   In MATLAB this is rng(s), i.e. exactly what the original script used, so
%   the noise realisation of the published figures is reproduced.  Other
%   interpreters use a different generator, so their noise differs in detail
%   (the results are qualitatively identical).
if exist('rng','file') || exist('rng','builtin')
    rng(s);
else
    randn('state', s);   %#ok<RAND>
    rand('state', s);    %#ok<RAND>
end
end
