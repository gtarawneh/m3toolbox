% generates chequerboard-like pattern
%
% W         : pattern width (px)
% H         : pattern height (px)
% blockSize : chequer size (px)
% random    : 0 = regular pattern, 1 = random pattern
% lum0      : luminance level of 0 blocks (default = 0)
% lum1      : luminance level of 1 blocks (default = 1)
% equalize  : if 1 then 0 and 1 blocks have equal counts
% rshift    : if 1 then a random grid offset will be introduced
% rseed     : when specified, generates a unique pattern based on rseed
%
% note about generating patterns using rseed:
% - to reproduce the same pattern generated using an rseed value, you must
% supply the same values to other parameters. In other words, the patterns
% generated by (W=10, H=10, rseed=5, equalize01=0) and (W=10, H=10,
% rseed=5, equalize=1) are NOT the same (different equalize01 values).
%
% Ghaith Tarawneh (ghaith.tarawneh@ncl.ac.uk) - 4/6/2015

function chequer = genChequer(args)

% parameters

W = 100;

H = 100;

blockSize = 10;

random = 1;

lum0 = 0;

lum1 = 1;

equalize01 = 1;

rshift = 0;

rseed = [];

if nargin>0
    
    unpackStruct(args);
    
end

%% body

if rshift && equalize01
    
    error('bug equalization (equalize01) can''t be used with random shift (rshift)');
    
end

blocks = ceil([W H] / blockSize);

blocks = blocks + [1 1] * rshift; % add a row and col when rshift = 1

if random
    
    if ~isempty(rseed)
        
        oldGenerator = rng;
        
        rng(rseed);
    
    end
    
    if equalize01
        
        pattern = randEqualize(blocks);
        
    else
        
        pattern = rand(blocks) > 0.5; %#ok
        
    end   
    
    if ~isempty(rseed);
        
        rng(oldGenerator);
        
    end
    
else
    
    [x, y] = meshgrid(1:blocks(2), 1:blocks(1)); %#ok
    
    pattern = mod(x+y, 2);
    
end

pattern = (1-pattern) * lum0 + (pattern) * lum1;

chequer = imresize(pattern, blockSize, 'nearest');

xs = rshift * randi([1 blockSize]);
ys = rshift * randi([1 blockSize]);

chequer = chequer((1:W) + xs, (1:H) + ys);

chequer = chequer';

end

function pattern = randEqualize(blocks)

n = prod(blocks);

vec = (1:n) > n/2;

k = randperm(n);

pattern = reshape(vec(k), blocks);

end