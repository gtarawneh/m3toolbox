function runMantisExperimentDynamicAnaglyph()

expt = struct;

expt.genParamSetFun = @genParamSet;

expt.runBeforeTrialFun = @runBeforeTrial;

expt.runTrialFun = @runTrial;

expt.runAfterTrialFun = @runAfterTrial;

expt.workDir = 'V:\readlab\Ghaith\m3\data\mantisDynamicAnaglyph\';

expt.name = 'Mantis Camouflaged Dynamic Anaglyph';

expt.recordVideos = 1;

expt.makeBackup = 1;

expt.defName = 'Vivek';

runExperiment(expt);

end

function paramSet = genParamSet()

blocks = 10;

viewD = input('Enter distance between mantis and screen (cm): ');

paramSet = createRandTrialBlocks(blocks, [-1 0 +1], viewD);

end

function runBeforeTrial(paramSetRow)

disp('pre trial');

expt = struct();

expt.enableKeyboard = 0;

expt.disparityEnable = paramSetRow(1);

expt.bugY = -100; % hide bug

expt.interTrialTime = 0;

expt.preTrialDelay = 59;

expt.motionDuration = 1;

expt.finalPresentationTime = 0;

expt.viewD = paramSetRow(2);

runDynamicAnaglyph(expt);

end

function [exitCode, dump] = runTrial(paramSetRow)

disp('rendering the stimulus ...');

expt = struct;

expt.enableKeyboard = 0;

expt.disparityEnable = paramSetRow(1);

expt.viewD = paramSetRow(2);

expt.interTrialTime = 0;

expt.preTrialDelay = 0;

runDynamicAnaglyph(expt);
    
exitCode = 0;

dump = 0;

end

function resultRow = runAfterTrial(varargin)

resultRow = 0;

end