function [exitCode, clickPoints] = runFlashColoration(args)

% parameters

bugHeight = 100; % pixels

bugDimension = bugHeight * 2; % bug texture size (px)

bodyLateral = 2/3; % relative size of bug body part (1 = equilateral)

wingLateral = 1; % relative size of bug wing part (1 = equilateral)

wing = nan; % inf (same as bug), nan (1/f), scalar (lum) or RGB triplet

bugAngle = randi(360); % bug orientation angle in degrees (0 = leftwards)

motionDistance = randi([200 600]); % distance travelled (px)

bugSpeed = 500; % bug speed (px/sec)

videoFile = ''; % leave empty to disable recording

recordingFrameRate = 60; % fps

postMotionDelay = 0; % seconds

preMotionDelay = 0; % seconds

drawDebugLines = 1; % draw lines across the screen for debugging

% bugBody:
%
% nan         : 1/f pattern
% scalar      : luminance value [0, 1]
% vector      : RGB triplet
% 'background': cut from background at final position

bugBody = [1 0 0];

% motionTrigger
%
% 'auto' : motion starts automatically
% 'buff' : motion starts when cursor enters buffer area

motionTrigger = 'buff';

bufferRadius = 100; % pixels

% isBodyVisible
%
% Determine when body part is visible.
%
% t               : time after motion trigger is fired (seconds)
% inMotion        : 1 if bug currently moving, 0 otherwise
% motionTriggered : 1 if trigger fired, 0 otherwise

isBodyVisible = @(t, inMotion, motionTriggered) inMotion;

% bugInitialPosition
%
% Position of bug *center*
%
% Calculate the default value such that the bug travels towards screen
% center.

bugInitialPos = round([1920 1200]/2 - ...
    [cosd(bugAngle) -sind(bugAngle)] * motionDistance);

%%

if nargin

    unpackStruct(args);

end

%% quick checks

iseven = @(x) mod(x, 2) == 0;

assert(iseven(bugDimension));

assert(motionDistance >= 0, 'motionDistance is negative');

%% create window

KbName('UnifyKeyNames');

createWindow();

[sW, sH] = getResolution();

window = getWindow();

%% generate patterns

backPattern = genNaturalPattern(struct('makePlot', 0, 'W', sW, 'H', sH));

backPattern = transp(backPattern);

if isequal(bugBody, 'background')

    xBackPat = bugFinalPosition(1) + (1:bugDimension) - bugDimension/2;
    yBackPat = bugFinalPosition(2) + (1:bugDimension) - bugDimension/2;

    bugBodyContent = backPattern(yBackPat, xBackPat);

else

    bugBodyContent = bugBody;

end

bugBodyPattern = genFlashColorationBug(struct( ...
    'bugHeight', bugHeight, ...
    'id', nan, ...
    'bugLateral', bodyLateral, ...
    'bugBodyContent', bugBodyContent, ...
    'd', bugDimension, ...
    'bugAngle', bugAngle));

% wingHeightCorrection is used to subtract 1 from wing pattern height;
% this avoids an off-by-one rendering issue where conspicuous wing pattern
% overflows bug pattern. This correction is applied when wing content is
% not the same as bug pattern.

wingSameBugPattern = isinf(wing);

bugWingPattern = genFlashColorationBug(struct( ...
    'bugHeight', bugHeight, ...
    'id', nan, ...
    'bugLateral', wingLateral, ...
    'bugBodyContent', ifelse(wingSameBugPattern, bugBodyContent, wing), ...
    'd', bugDimension, ...
    'bugAngle', bugAngle));

%% render

clickPoints = []; % holds click (x, y, t) coordinates

bugPosPoints = []; % holds bug (x, y, t) coordinates

% Note: in clickPoints and bugPosPoints, t=0 corresponds to the start of
% bug motion

[~, ~, old_buttons] = GetMouse(window); % old button state (for comparison)

[h, w, ~] = size(bugBodyPattern);

makeTexture = @(pat) Screen('MakeTexture', window, pat * 255);

bug_txt = makeTexture(bugBodyPattern);
back_txt = makeTexture(backPattern);
wing_txt = makeTexture(bugWingPattern);

vx = bugSpeed * cosd(bugAngle); % velocity x component (px/sec)
vy = bugSpeed * sind(bugAngle); % velocity y component (px/sec)

% These assertions check whether the bug is within screen at all times.
% They are disabled for now since some experiments require the bug to go
% off-screen.
%
% assert((bugFinalPosition(1) + dx) > 0);
% assert((bugFinalPosition(2) + dy) > 0);
% assert((bugFinalPosition(1) + dx) < sW);
% assert((bugFinalPosition(2) + dy) < sH);

duration = motionDistance / bugSpeed; % movement duration (seconds)

recording = recordStimulus(videoFile);

endRecording = @() recordStimulus(recording);

obj1 = onCleanup(endRecording);

t = 0;

% initial motionTriggered is false, unless motionTrigger equals 'auto'

motionTriggered = isequal(motionTrigger, 'auto');

while 1

    if motionTriggered

        frame = frame + 1;

        tReal = GetSecs() - t0;

        tFrames = frame / recordingFrameRate;

        t = ifelse(isempty(recording), tReal, tFrames);

        t = max(t - preMotionDelay, 0);

        [mx, my, buttons] = GetMouse(window);

        if buttons(1) && ~old_buttons(1)

            fprintf('Click at %f, %d, %d\n', t, mx, my);

        end

        old_buttons = buttons;

    else

        % check trigger

        if isequal(motionTrigger, 'auto')

            t0 = GetSecs();

            frame = 0;

            motionTriggered = 1;

        elseif isequal(motionTrigger, 'buff')

            [mx, my] = GetMouse(window);

            mouseDiff = [mx my] - bugInitialPos;

            mouseDist = sqrt(sum(mouseDiff .^ 2));

            if mouseDist < bufferRadius

                t0 = GetSecs();

                frame = 0;

                motionTriggered = 1;

            end

        end


    end

    % calculate relative displacement from initial position

    xr = ifelse(t < duration, vx * t, vx * duration);
    yr = ifelse(t < duration, vy * t, vy * duration) * -1;

    % note: when calculating yr, multiply by -1 because the positive
    % direction of bugAngle y-axis points opposite to screen y-axis.

    inMotion = (t > 0) && (t < duration);

    xr = round(xr);
    yr = round(yr);

    % calculate bug coordinate box

    bugRect = [0 0 w h];

    bugPos = bugRect ...
        + bugInitialPos([1 2 1 2]) ...
        + [xr yr xr yr] ...
        - [1 1 1 1] * bugDimension/2;

    % draw textures

    Screen('FillRect', window, 255);

    Screen('DrawTexture', window, back_txt);

    Screen('DrawTexture', window, wing_txt, bugRect, bugPos, 0);

    if drawDebugLines

        Screen('DrawLine', window, [1 0 0], 0, sH/2, sW, sH/2, 1);

        Screen('DrawLine', window, [1 0 0], sW/2, 0, sW/2, sH, 1);

        if ~motionTriggered

            bufferRect = ...
                bugInitialPos([1 2 1 2]) + [-1 -1 1 1] * bufferRadius;

            Screen('FrameOval', window, [1 0 0], bufferRect);

        end

    end

    if isBodyVisible(t, inMotion, motionTriggered)

        Screen('DrawTexture', window, bug_txt, bugRect, bugPos, 0);

    end

    Screen('Flip', window);

    recording = recordStimulus(recording);

    % checking for key presses

    [~, ~, keyCode ] = KbCheck;

    if (keyCode(KbName('Escape')))

        exitCode = 1;

        return

    end

    if (keyCode(KbName('End')))

        exitCode = 2;

        return

    end

    if t > (duration + postMotionDelay)

        exitCode = 0;

        return

    end

end

end
