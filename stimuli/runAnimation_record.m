% This script is the main rendering engine for checkerboard patterns.
%
% It supports two running modes: "Interactive" where the user can adjust
% the stimulus parameters on the fly using keyboard shortcuts and
% "non-interactive" which is a rendering of a pre-defined stimulus.
%
function [DXs, Ts, t, exitCode, dump] = runAnimation_record(expt)

KbName('UnifyKeyNames');

createWindow();

window = getWindow();

resetWindow();

exitCode = 0;
% 
% -------------------------------------------------------------------------
%
% General Settings:
%
% -------------------------------------------------------------------------

interactiveMode = 0;

timeLimit = 0; % in seconds (0 to disable)

closeOnFinish = 0;

% -------------------------------------------------------------------------
%
% Stimulus Specifications:
%
% M             : resolution (pixels)
% txtCount      : requested number of textures
% R             : white tile percentage ([0, 1])
% textured      : use slightly textured tiles instead of monochromatic ones
% camouflage    : enable bug camouflage
%
% The stimulus must run in full screen and so not all integer M values are
% accepted (depending on screen aspect ratio). Incorrect M values will
% generate a warning and dbefault to M=1
%
% -------------------------------------------------------------------------

M = 40;

txtCount = 50; % don't bother

R = 0.5; % don't bother

textured = 0; % don't bother

camouflage = 0;

dynamicBackground = 0;

% -------------------------------------------------------------------------
%
% DX Function:
%
% -------------------------------------------------------------------------

funcMotionX = @(t) 500 * t;

stepDX = 150; % in pixels

% -------------------------------------------------------------------------
%
% Bug shape, motion, size and visibility:
%
% -------------------------------------------------------------------------

bugFrames = getBugFrames('fly'); % stick, beetle, fly

motionFuncs = getMotionFuncs('swirl', 0, 0); % horizontal, zigzag, swirl, auto, keyboard

nominalSize = 0.5;

bugVisible = 0;

% -------------------------------------------------------------------------
%
% User functions:
%
% -------------------------------------------------------------------------

funcRender = @(window, t, sW, sH) 0;

start = @(window, t, sW, sH) 0;

abort = @(window, t, sW, sH) 0;

% -------------------------------------------------------------------------
%
% Reloading settings from expt
%
% -------------------------------------------------------------------------

if nargin>0

	% note: the code below overrides some of the default parameters by
	% unpacking the structure `expt`. The method below is obselete
	% and will be replaced by a call to loadExpt() in the future.
    
    unpackStruct(expt);
    
end

% -------------------------------------------------------------------------
%
% Print available commands
%
% -------------------------------------------------------------------------

if (interactiveMode == 2)
    
    arr = {
        ' Key'  , 'Function', ...
        '---------'  , '--------', ...
        'a'     , 'motion mode: auto', ...
        's'     , 'motion mode: swirl', ...
        'k'     , 'motion mode: keyboard', ...
        'h'     , 'motion mode: horizontal', ...
        ''      , '', ...
        'ctrl'  , 'highlight bug', ...
        'b'     , 'show bug', ...
        'n'     , 'hide bug', ...
        ''      , '', ...
        '1'     , 'bug shape: fly', ...
        '2'     , 'bug shape: beetle', ...
        '3'     , 'bug shape: stick', ...
        ''      , '', ...
        'Page Up', 'scroll background: right', ...
        'Page Down', 'scroll background: left', ...
        'w'     , 'change background', ...
        };
    
    home;
    
    
    for i=1:2:length(arr)
        
        fprintf('%10s \t %s\n', arr{i}, arr{i+1});
        
    end
    
    disp(' ');
    
end


% -------------------------------------------------------------------------
%
% Function Body:
%
% -------------------------------------------------------------------------

% getting screen resolution (sW x sH) and board dimensions (w x h)

[sW, sH] = getResolution();

[w, h] = rat(sW/sH);

w = w * 1;
h = h * 1;

%sW = ceil(sW / M / 2) * M * 2
%sH = ceil(sH / M / 2) * M * 2

% determining maximum side length of block that would fit w times h blocks
% within the screen resolution:

n1 = floor(sW/w);
n2 = floor(sH/h);

blockSide = min(n1, n2);

N = blockSide/M;

Ms = getMs();

if ~ismember(M, Ms)
    
    disp(['Incorrect m value (supported ones are ' num2str(Ms) ') default to m=1']);
    
    N = blockSide;

end

blockSide = blockSide - mod(blockSide, N);

marginRight = (sW - blockSide * w) / 2;
marginTop   = (sH - blockSide * h) / 2;

if marginRight + marginTop>0
    disp('Warning, not running in full screen!');
end

% preparing textures:

tileSide = blockSide/N;

txtID = zeros(2, 1);

%fprintf('uploading %i textures of size %ix%i to VRAM ... ', txtCount, blockSide, blockSide); drawnow

if (textured)
    
    tile(:,:,1) = 0   + 50 * rand(tileSide, tileSide);
    tile(:,:,2) = 200 + 50 * rand(tileSide, tileSide);
    
else
    
    tile(:,:,1) = ones(tileSide, tileSide) * 0;
    tile(:,:,2) = ones(tileSide, tileSide) * 150;
    
end

% prepare two blocks B1 (containing only tile 0) and B2 (containing
% only tile 1)

B1 = repmat(tile(:, :, 1), N);
B2 = repmat(tile(:, :, 2), N);

% prepare the vector K which is used in pattern inflation below

K = ceil((1:N*tileSide) / tileSide);

% calculating absolute maximum number of textures

txtCountMax = 2^(N*N);

% preventing txtCount > txtCountMax

txtCount = min(txtCount, txtCountMax);

% creating and uploading textures to VRAM

for i=1:txtCount
    
    %texture = zeros(blockSide, blockSide);
    
    if (txtCount >= txtCountMax)
        
        % if number of textures equals or exceed theoritical maximum, enumerate all
        % possible texture permutations
        
        pattern = vec2mat(dec2bin(i-1, N^2)-48, N);
        
    else
        
        % otherwise, choose random permutations
        
        pattern = rand(N, N) > R;
        
    end
    
    % the two lines below prepare the matrix mask which is essentially
    % an "inflated" copy of pattern, for example:
    %
    % for pattern:
    %
    % 0 1
    % 1 0
    %
    % mask would be:
    %
    % 0 0 1 1
    % 0 0 1 1
    % 1 1 0 0
    % 1 1 0 0
    %
    % Each row and column is duplicated by tileSide (2 in the example
    % above)
    
    mask = pattern(K, K);
    
    % now, mask is used to combine portions of B1 and B2 to create the
    % texture
    
    texture = mask .* B1 + (1-mask) .* B2;
    
    % upload texture and store returned handle
    
    txtID(i) = Screen(window, 'MakeTexture', texture);
    
end

tileID{1} = Screen(window, 'MakeTexture', tile(:, :, 1));
tileID{2} = Screen(window, 'MakeTexture', tile(:, :, 2));

%disp('done'); toc; drawnow

fCount = length(bugFrames);

[bugHeight, bugWidth] = size(bugFrames{1}); % in tiles

% preparing bug camouflage mask

bugCamMask = rand(size(bugFrames{1})) > 0.5;

% user function

start(window, sW, sH);

% creating workspace dump

dump = packWorkspace();

% rendering loop:

i = 0; % current frame

dx = 0;

board = [];

startTime = GetSecs();

DXs = [];

Ts = [];

writerObj = VideoWriter('d:\run_animation_video.avi');

writerObj.FrameRate = 60;

open(writerObj);

while(1)
    
    i = i + 1;
    
    %t = i/frameRate;
    
    %t = GetSecs - startTime;
    
    t = i / 60;
    
    if (t>6)
        break;
    end
    
    if timeLimit>0 && t >= timeLimit
        
        break;
        
    end
    
    % draw board
    
    if (interactiveMode == 0)
        
        dx = ceil(funcMotionX(t)/stepDX) * stepDX;
        
        DXs = [DXs dx];
        
        Ts = [Ts t];
        
    end
    
    %dy = ceil(t*200);
    
    
    
    %dx = ceil(t*400);
    
    dy = 0;
    
    if isempty(board) || dynamicBackground
        
        board = floor(rand(h+2, w+2) * txtCount);
        
    end
    
    for x=1:w
        
        drawRow(window, x, txtID, h, board, blockSide, [marginRight marginTop marginRight marginTop], dx, dy, sW, sH)
        
    end
    
    % draw bug
    
    if (bugVisible)
        
        ym = floor((h * N - bugHeight)/2);
        
        xm = floor((w * N - bugWidth)/2);
        
        %if mod(i,10) == 1
        d = motionFuncs.XY(t);
        %end
        bdx = d(1);
        bdy = d(2);
        
        %dy = motionFuncs.Y(t);
        
        bugCenter(1) = (xm + bugWidth/2) * tileSide + bdx;
        bugCenter(2) = (ym + bugHeight/2) * tileSide + bdy;
        
        bugAngle = motionFuncs.Angle(t);
        
        bugSize = motionFuncs.S(t) * nominalSize;
        
        % rotate and scale bug
        
        rotateWindow(bugCenter, bugAngle);
        
        scaleWindow(bugCenter, bugSize);
        
        % draw marker
        
        [~, ~, keyCode ] = KbCheck;
        
        if (keyCode(KbName('Control')))
            
            highR = tileSide * 20;
            
            bc = bugCenter + [0 tileSide];
            
            Screen(window, 'FrameOval', [1 0 0 1], [bc-highR bc+highR] , 2);
            
            Screen(window, 'FillOval',  [0.9 0 0 0.3], [bc-highR bc+highR]);
            
        end
        
        % draw bug tiles:
        
        f = mod(floor(motionFuncs.F(t)), fCount) + 1; % frame number
        
        for y=1:bugHeight
            
            for x=1:bugWidth
                
                if bugFrames{f}(y, x)
                    
                    % tile = ;
                    
                    sourceRec = [0 0 1 1] * tileSide;
                    
                    destRec = sourceRec;
                    
                    destRec = destRec + [(xm + x-1) ym+y (xm + x-1) ym+y] * tileSide;
                    
                    destRec = destRec + [marginRight marginTop marginRight marginTop] - 1;
                    
                    destRec = destRec + [bdx bdy bdx bdy];
                    
                    m = 2 - (bugCamMask(y, x) || ~camouflage);
                    
                    Screen(window, 'DrawTexture', tileID{m}, sourceRec, destRec);
                    
                end
                
            end
            
        end
        
        % reverse (rotate and scale) after drawing bug
        
        rotateWindow(bugCenter, -bugAngle);
        
        scaleWindow(bugCenter, 1/bugSize);
        
    end
    
    % user function
    
    funcRender(window, t, sW, sH);
    
    % render drawings
    
    Screen(window, 'Flip');
    
    % checking for key presses
    
    [~, ~, keyCode ] = KbCheck;
    
    if (keyCode(KbName('Escape')))
        
        if (timeLimit == 0) % if in interactive mode
            
            exitCode = -1; % abort
            
            break;
            
        end
        
    end
    
    if (interactiveMode == 1)
        
        if (keyCode(KbName('s')))
            
            motionFuncs = getMotionFuncs('swirl');
            
            startTime = GetSecs();
            
        end
        
        if (keyCode(KbName('a')))
            
            motionFuncs = getMotionFuncs('auto');
            
            startTime = GetSecs();
            
        end
        
        if (keyCode(KbName('j')))
            
            motionFuncs = getMotionFuncs('zigzag');
            
            startTime = GetSecs();
            
        end
        
        if (keyCode(KbName('c')))
            
            motionFuncs = getMotionFuncs('circle');
            
            startTime = GetSecs();
            
        end
        
        if (keyCode(KbName('k')))
            
            motionFuncs = getMotionFuncs('keyboard');
            
            startTime = GetSecs();
            
        end
        
        if (keyCode(KbName('h')))
            
            motionFuncs = getMotionFuncs('horizontal');
            
            startTime = GetSecs();
            
        end
        
        if (keyCode(KbName('b')))
            
            bugVisible = 1;
            
        end
        
        if (keyCode(KbName('n')))
            
            bugVisible = 0;
            
        end
        
        if (keyCode(KbName('w')))
            
            board = floor(rand(h, w*3) * txtCount);
            
        end
        
        
        
        if (keyCode(KbName('1!')))
            
            bugFrames = getBugFrames('fly');
            
            [bugHeight, bugWidth] = size(bugFrames{1}); % in tiles
            
            bugCamMask = rand(size(bugFrames{1})) > 0.5;
            
        end
        
        if (keyCode(KbName('2@')))
            
            bugFrames = getBugFrames('beetle');
            
            [bugHeight, bugWidth] = size(bugFrames{1}); % in tiles
            
            bugCamMask = rand(size(bugFrames{1})) > 0.5;
            
        end
        
        if (keyCode(KbName('3#')))
            
            bugFrames = getBugFrames('stick');
            
            [bugHeight, bugWidth] = size(bugFrames{1}); % in tiles
            
            bugCamMask = rand(size(bugFrames{1})) > 0.5;
            
        end
        
        if (keyCode(KbName('PageUp')))
            
            dx = dx + 10;
            
        end
        
        if (keyCode(KbName('PageDown')))
            
            dx = dx - 10;
            
        end
        
        if (keyCode(KbName('x')))
            
            nominalSize = nominalSize + 0.01;
            
        end
        
        if (keyCode(KbName('z')))
            
            nominalSize = nominalSize - 0.01;
            
        end
        
    end
    
    % user functions
    
    if (abort(window, t, sW, sH))
        
        break;
        
    end
    
    if (mod(i, 10) == 0 && interactiveMode == 1)
        
        drawnow
        
    end
    
    imageArray = Screen(window, 'GetImage');
    
    writeVideo(writerObj, imageArray);
    
end

if closeOnFinish
    
    closeWindow();
    
end

close(writerObj);



end

function drawRow(window, x, txtID, h, board, blockSide, margins, dx, dy, sW, ~)

for y=1:h
    
    id = board(y, x) + 1;
    
    sourceRec = [0 0 1 1] * blockSide;
    
    destRec = sourceRec + [x-1 y-1 x-1 y-1] * blockSide + margins;
    
    destRec = destRec + [dx 0 dx 0];
    
    destRec = destRec + [0 dy 0 dy];
    
    % x block relocation 1
    
    k = destRec(1);
    d = destRec(3) - destRec(1);
    
    q = mod(k-1, sW) + 1;
    
    destRec(1) = q;
    destRec(3) = q + d;
    
    Screen(window, 'DrawTexture', txtID(id), sourceRec, destRec);
    
    % x block relocation 2
    
    k = destRec(3);
    d = destRec(1) - destRec(3);
    
    q = mod(k-1, sW) + 1;
    
    destRec(3) = q;
    destRec(1) = q + d;
    
    Screen(window, 'DrawTexture', txtID(id), sourceRec, destRec);
    
end



end