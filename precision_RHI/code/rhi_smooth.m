function B = rhi_smooth(A, win)
%RHI_SMOOTH  Gaussian moving average along TIME (the second dimension).
%
%   B = RHI_SMOOTH(A,win) smooths each row of A (channels x time) with a
%   gaussian window of length WIN.  In MATLAB this is exactly
%   smoothdata(A,2,'gaussian',win), i.e. the original script's
%   smoothdata(A','gaussian',win)'.
%
%   NOTE the dimension: A is channels x time, so the smoothing runs along
%   dim 2.  Smoothing dim 1 instead averages the four lambda channels together
%   and leaves the step in time unsmoothed, which silently destroys the
%   covered-hand result (the Av precision no longer collapses, so M1 is never
%   penalised and no model switch occurs).
%
%   The fallback below is for interpreters without smoothdata (e.g. Octave) and
%   is only approximately identical, so the shape of the lambda transition may
%   differ slightly outside MATLAB.

if exist('smoothdata','file') || exist('smoothdata','builtin')
    B = smoothdata(A, 2, 'gaussian', win);
    return
end

n     = size(A,2);
sigma = win/5;                       % MATLAB's convention
lo    = -floor(win/2);               % even win -> window is [i-w/2, i+w/2-1]
hi    = lo + win - 1;
off   = lo:hi;
wts   = exp(-0.5*((off - mean([lo hi]))/sigma).^2);

B = zeros(size(A));
for i = 1:n
    j    = i + off;
    keep = j >= 1 & j <= n;          % truncate at the ends, renormalise
    ww   = wts(keep);  ww = ww/sum(ww);
    B(:,i) = A(:,j(keep)) * ww(:);
end
end
