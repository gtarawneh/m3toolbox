function runHumanExperimentFlashColoration()

expt = struct;

expt.genParamSetFun = @genParamSetB;

expt.runTrialFun = @(varargin) []; % dummy

expt.runAfterTrialFun = @runAfterTrial;

expt.runBeforeTrialFun = @(varargin) []; % dummy

expt.workDir = 'd:\m3\data\humanFlashColoration\';

expt.name = 'Human Flash Coloration';

expt.defName = 'Sabrina';

expt.recordVideos = 0;

expt.makeBackup = 1;

expt.addTags = {'200'};

runExperiment(expt);

end

function paramSet = genParamSetB()

directions = [-1 1];

conditions = 1:10;

paramSet = createRandTrialBlocks(10, directions, conditions);

assert(size(paramSet, 1) == 200);

end

function paramSet = genParamSet()

directions = [-1 1];

% Diana: There will be 6 repetition per conditions for the stationary
% target = Cs and Fs, 6 each.

% GT: Create 3 blocks of 2 directions times [Cs, Fs].

staticConds = createTrialBlocks(3, directions, [1 2]);

assert(size(staticConds, 1) == 12); % must equal 12 trials

% There will be 12 repetitions each per the testing conditions what
% moves=C, F1 and F2. The moving target will have the reps divided equally
% per distance (6 and 6) and direction of motion (3 and 3).

% C-6   : condition 3
% C-12  : condition 4
% F1-6  : condition 5
% F1-12 : condition 6
% F2-6  : condition 7
% F2-12 : condition 8

% GT: Create 3 blocks of 2 directions times condition in [3:8].

movingConds = createTrialBlocks(3, directions, 3:8);

assert(size(movingConds, 1) == 36);

% Diana: The distractors will have only 4 repetition per each
% condition, D1 and D2.

% GT: Create 2 blocks of 2 directions times condition in [9 10].

distConds = createTrialBlocks(2, directions, [9 10]);

assert(size(distConds, 1) == 8);

% GT: Combine conds

conds = [staticConds; movingConds; distConds];

assert(size(conds, 1) == 56);

randOrder = createRandTrial(1:56);

paramSet = conds(randOrder, :);

end

function resultRow = runAfterTrial(paramSetRow)

bugDir = paramSetRow(1);

condition = paramSetRow(2);

[exitCode, results] = runColorationTrial(bugDir, condition);

if ismember(exitCode, [1 2])
    
    error('Experiment aborted');
    
end

caughtBug = exitCode == 3;

showTick = caughtBug;

resultRow = results;

symbol = ifelse(showTick, 'tick', 'cross');

showSymbol(symbol);

pause(3);

end

%% Stimulus Wrapper

function [exitCode, results] = runColorationTrial(bugDir, condition)

    recordGaze = 0;

    [sW, sH] = getResolution();

    bugHeight = 100; % px (tip to base)

    bugY = sH/2; % bug y position (px)

    bugSpeed = 800; % px/sec

    margin = bugHeight;

    makePlot = 0;

    x1 = margin; x2 = sW - margin; % lower/upper limits of bug end position (px)

    %% Eyelink

    createWindow(); % required for Eyelink wrappers

    if recordGaze

        openEyelink(); %#ok<UNRCH>

        file = startEyelinkRecording();

        obj1 = onCleanup(@closeEyelink);

        onStart = @() tagEyelink('Start');

        onTrigger = @() tagEyelink('Trigger');

    else

        onStart = @() disp('Stimulus started ...');

        onTrigger = @() disp('Motion triggered ...');

    end

    %% Sanity checks

    % Check that x1 and x2 do not cause the bug to be out of the screen

    assert(x1 > bugHeight/2, 'x1 too small');

    assert(x2 < sW - bugHeight/2, 'x2 too large');

    %% Condition logic

    % For each condition, decide:
    %
    % distance: travelled distance, in integer multiples of bug height
    %
    % isBodyVisible: lambda specifying when is the colored body part visible
    %
    % postMotionDelay: delay after end of motion (seconds)

    staticBugPostMotion = 60;

    movingBugPostMotion = 60;

    distractorBugPostMotion = 0;

    % Travelled distances are expressed with respect to distanceUnit.

    % The side length of an equilateral triangle (a) and its height (h) are
    % related by h = a sin(60)
    %
    % Source: http://mathworld.wolfram.com/EquilateralTriangle.html

    % bugSideLength = bugHeight / sind(60); % don't need this for now

    distanceUnit = round(bugHeight);

    if condition == 1

        % Cs (static bug, cryptic all the time)

        isBodyVisible = @(varargin) false;

        postMotionDelay = staticBugPostMotion;

        [bugLeft, bugRight] = getMotionLimits(x1, x2, 0);

    elseif condition == 2

        % Fs (static bug, flash-coloration after detection)

        isBodyVisible = @(t, inMotion, motionTriggered) motionTriggered;

        postMotionDelay = staticBugPostMotion;

        [bugLeft, bugRight] = getMotionLimits(x1, x2, 0);

    elseif condition == 3

        % C-6 (moving bug, cryptic)

        distance = 6;

        isBodyVisible = @(varargin) false;

        postMotionDelay = movingBugPostMotion;

        [bugLeft, bugRight] = ...
            getMotionLimitsBothInside(x1, x2, distance * distanceUnit);

    elseif condition == 4

        % C-12 (moving bug, cryptic)

        distance = 12;

        isBodyVisible = @(varargin) false;

        postMotionDelay = movingBugPostMotion;

        [bugLeft, bugRight] = ...
            getMotionLimitsBothInside(x1, x2, distance * distanceUnit);

    elseif condition == 5

        % F1-6 (moving bug, distance 6, flash colored all the way)

        distance = 6;

        isBodyVisible = @(t, inMotion, motionTriggered) inMotion;

        postMotionDelay = movingBugPostMotion;

        [bugLeft, bugRight] = ...
            getMotionLimitsBothInside(x1, x2, distance * distanceUnit);

    elseif condition == 6

        % F1-12 (moving bug, distance 12, flash colored all the way)

        distance = 12;

        isBodyVisible = @(t, inMotion, motionTriggered) inMotion;

        postMotionDelay = movingBugPostMotion;

        [bugLeft, bugRight] = ...
            getMotionLimitsBothInside(x1, x2, distance * distanceUnit);

    elseif condition == 7

        % F2-6 (moving bug, distance 6, flash colored for 4 distance units)

        distance = 6;

        bodyDistance = (distance - 2) * distanceUnit;

        bodyVisibleDuration = bodyDistance / bugSpeed;

        isBodyVisible = @(t, inMotion, motionTriggered) ...
            inMotion && (t < bodyVisibleDuration);

        postMotionDelay = movingBugPostMotion;

        [bugLeft, bugRight] = ...
            getMotionLimitsBothInside(x1, x2, distance * distanceUnit);

    elseif condition == 8

        % F2-12 (moving bug, distance 12, flash colored for 10 distance
        % units)

        distance = 12;

        bodyDistance = (distance - 2) * distanceUnit;

        bodyVisibleDuration = bodyDistance / bugSpeed;

        isBodyVisible = @(t, inMotion, motionTriggered) ...
            inMotion && (t < bodyVisibleDuration);

        postMotionDelay = movingBugPostMotion;

        [bugLeft, bugRight] = ...
            getMotionLimitsBothInside(x1, x2, distance * distanceUnit);

    elseif condition == 9

        % D1 (moving bug, moves until outside screen, cryptic all the way)

        isBodyVisible = @(varargin) false;

        postMotionDelay = distractorBugPostMotion;

        bugLeft = randi([x1 x2]);

        bugRight = sW + bugHeight; % end position is off screen

    elseif condition == 10

        % D2 (moving bug, moves until outside screen, flash colored all the
        % way)

        isBodyVisible = @(t, inMotion, motionTriggered) inMotion;

        postMotionDelay = distractorBugPostMotion;

        bugLeft = randi([x1 x2]);

        bugRight = sW + bugHeight; % end position is off screen

    else

        error('unrecognized condition');

    end

    %% Render

    % See note in section 'Limit functions' below on naming conventions,
    % i.e. distinction between bugLeft, bugRight and bugStart

    bugStart = ifelse(bugDir == 1, bugLeft, sW - bugLeft);

    motionDistance = abs(bugRight - bugLeft);

    [exitCode, results] = runFlashColoration(struct( ...
            'wing', nan, ...
            'onStart', onStart, ...
            'bugBody', [1 0 0], ...
            'bugSpeed', bugSpeed, ...
            'bugAngle', ifelse(bugDir == 1, 0, 180), ...
            'onTrigger', onTrigger, ...
            'bodyLateral', 0.5, ...
            'bugInitialPos', [bugStart bugY], ...
            'isBodyVisible', isBodyVisible, ...
            'motionDistance', motionDistance, ...
            'postMotionDelay', postMotionDelay, ...
            'previewInsideClicks', 0, ...
            'escapeOnCatch', 1, ...
            'enableEscape', 1 ...
        ));

    %% Save Eyelink recording data

    if recordGaze

        ds = datestr(now, 'yyyy-mm-dd-HH-MM-SS'); %#ok<UNRCH>

        output_file = sprintf('d:/flash-coloration-data/trial_%s.edf', ds);

        finishEyelinkRecording(file, output_file);

    end

    %% Plot

    if makePlot

        plotResults(results); %#ok<UNRCH>

    end

end

function plotResults(results)

    clf; hold on;

    bugPosPoints = results.bugPosPoints;

    triggerTime = results.triggerTime;

    clickPoints = results.clickPoints;

    plot(bugPosPoints(:, 1), bugPosPoints(:, 2)); % bug position

    plotMarker = @(t, varargin) plot([1 1] * t, [0 2000], varargin{:});

    plotMarker(triggerTime, 'r');

    nClicks = size(clickPoints, 1);

    for i=1:nClicks

        ct = clickPoints(i, 1); % click time

        cx = clickPoints(i, 2); % click horizontal value

        plot(ct, cx, 'ko');

    end

    xlabel('Time (seconds)');

    ylabel('Bug Horizontal Position (px)');

    ylim([0 2000]);

    grid on; box on;

end

%% Limit functions

% These are helper functions to select bug start and end positions
% (along the horizontal). x1 < x2 by definition meaning x1 is left and
% x2 is right. Elsewhere in the code these are referred to as bugLeft
% and bugRight correspondingly.

% Note that, when the bug is moving leftwards, the start position is
% bugRight. I've used the name 'bugStart' to refer to whichever of
% bugLeft/bugRight happens to be the starting position.

function [x1, x2] = getMotionLimitsBothInside(mn, mx, d)

% Return two values [x1, x2] in the range [mn, mx] subject to the following
% constraints:
%
% 1. x1 and x2 are both in [mn, mx]
% 2. x2 - x1 = d

x1_max = mx - d; % max value for x1 such that (x1 + d <= mx)

x1 = randi([mn x1_max]);

x2 = x1 + d;

end

function [x1, x2] = getMotionLimits(mn, mx, d)

% Return two values [x1, x2] where only x1 is in the range [mn, mx],
% subject to the following constraint:
%
% 1. x2 - x1 = d

x1 = randi([mn mx]);

x2 = x1 + d;

end
