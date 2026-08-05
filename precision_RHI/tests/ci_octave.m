% CI entry point for GNU Octave. In MATLAB just use SETUP_PATH + RUN_ALL_CHECKS;
% this only exists because Octave needs a graphics toolkit chosen explicitly on
% a headless runner, and that is not something the library code should do.
setup_path
if exist('OCTAVE_VERSION', 'builtin')
    graphics_toolkit('gnuplot');           % works without a display
    set(0, 'defaultfigurevisible', 'off');
end
run_all_checks
