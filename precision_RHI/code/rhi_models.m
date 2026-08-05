function [M1, M2, SM] = rhi_models(p)
%RHI_MODELS  The two competing internal models of reality (Eq 3, Eq 4).
%
%   [M1,M2,SM] = RHI_MODELS(p) builds the observation matrices that map
%   states X = [Ea Er Et Sy]' onto observations Y = [Av Rv At Py]'.
%
%     M1  "my hand is my real hand"    (Eq 3; also the generative process)
%     M2  "my hand is the rubber hand" (Eq 4)
%     SM  alpha-weighted mixture of the two (Eq 2), the "selected model"
%         used to represent a participant with susceptibility p.alpha:
%         alpha = +10 -> SM ~ M1,  alpha = -10 -> SM ~ M2,  alpha = 0 -> 50/50.
%
%   The only difference between M1 and M2 is which hand the tactile (row 3)
%   and proprioceptive (row 4) channels are read out from: the real hand (Ea)
%   in M1, the rubber hand (Er) in M2.  d = Ay - Ry is the inter-hand
%   distance and is the term that generates the proprioceptive drift.

d = p.Ay - p.Ry;

M1 = [ 0.8   0     0.2  0
       0     1     0    0
      -0.3   0     0.7  0
       d     0     0    1 ];

M2 = [ 0.8   0     0.2  0
       0     1     0    0
       0    -0.3   0.7  0
       0     d     0    1 ];

w1 = 1/(1 + exp(-p.alpha));        % weight of M1 in Eq (2)
SM = w1*M1 + (1-w1)*M2;
end
