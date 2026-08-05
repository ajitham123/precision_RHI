function idx = rhi_window(p, w)
%RHI_WINDOW  Sample indices of a time window given in seconds.
%   idx = RHI_WINDOW(p,[t0 t1]) returns find(p.t >= t0 & p.t <= t1).
idx = find(p.t >= w(1) & p.t <= w(2));
end
