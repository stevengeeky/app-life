
function [] = main()

if ~isdeployed
    switch getenv('ENV')
    case 'IUHPC'
        disp('loading paths (HPC)')
        addpath(genpath('/N/u/brlife/git/encode'))
        addpath(genpath('/N/u/brlife/git/vistasoft'))
        addpath(genpath('/N/u/brlife/git/jsonlab'))
    case 'VM'
        disp('loading paths (VM)')
        addpath(genpath('/usr/local/encode-mexed'))
        addpath(genpath('/usr/local/vistasoft'))
        addpath(genpath('/usr/local/jsonlab'))
    end
end

% load my own config.json
config = loadjson('config.json')

disp('loading dt6.mat')
dt6 = loadjson(fullfile(config.dtiinit, 'dt6.json'))
aligned_dwi = fullfile(config.dtiinit, dt6.files.alignedDwRaw)

[ fe, out ] = life(config, aligned_dwi);

out.stats.input_tracks = length(fe.fg.fibers);
out.stats.non0_tracks = length(find(fe.life.fit.weights > 0));
fprintf('number of original tracks	: %d\n', out.stats.input_tracks);
fprintf('number of non-0 weight tracks	: %d (%f)\n', out.stats.non0_tracks, out.stats.non0_tracks / out.stats.input_tracks*100);

disp('checking output')
if ~isequal(size(fe.life.fit.weights), size(fe.fg.fibers))
    disp('output weights and fibers does not match')
    disp(['fe.life.fit.weights', num2str(size(fe.life.fit.weights))])
    disp(['fe.fg.fibers', num2str(size(fe.fg.fibers))])
    exit;
end

disp('writing outputs')
save('output_fe.mat','fe', '-v7.3');

%used to visualize result on web
out.life = [];
savejson('out',  out,      'life_results.json');

%% for visualizing the tracks in viewer
% Extract the fascicles
fg = feGet(fe,'fibers acpc');

% Extract the fascicle weights from the fe structure
% Dependency "encode".
w = feGet(fe,'fiber weights');

% Eliminate the fascicles with non-zero entries
% Dependency "vistasoft"
fg = fgExtract(fg, w > 0, 'keep');
w = w(w>0)';

%cell2mat(fg.fibers');
fibers = fg.fibers(1:3:end);
fibers = cellfun(@(x) round(x,3), fibers, 'UniformOutput', false);

connectome.name = 'subsampled(30%). non-0 weighted life output';
connectome.coords = fibers';
connectome.weights = w(1:3:end);
%connectome.weights = w;

mkdir('tracts')
savejson('', connectome, fullfile('tracts', 'subsampledtracts.json'));

disp('saving product.json...')

% save life output to product.json
% create json structure...
% out = loadjson('life_results.json');
% out = out.out;
mat1 = out.plot{1};
mat2 = out.plot{2};

plot1 = struct;
plot2 = struct;
textual_output = struct;

plot1.data = struct;
plot1.layout = struct;
plot1.type = 'plotly';

plot1.data.x = mat1.x.vals;
plot1.data.y = mat1.y.vals;
plot1.data = {plot1.data};

plot1.layout.title = mat1.title;

plot1.layout.xaxis = struct;
plot1.layout.xaxis.title = mat1.x.label;
plot1.layout.xaxis.type = mat1.x.scale;

plot1.layout.yaxis = struct;
plot1.layout.yaxis.title = mat1.y.label;
plot1.layout.yaxis.type = mat1.y.scale;

plot2.data = struct;
plot2.layout = struct;
plot2.type = 'plotly';

plot2.data.x = mat2.x.vals;
plot2.data.y = mat2.y.vals;
plot2.data = {plot2.data};

plot2.layout.xaxis = struct;
plot2.layout.xaxis.title = mat2.x.label;
plot2.layout.xaxis.type = mat2.x.scale;

plot2.layout.yaxis = struct;
plot2.layout.yaxis.title = mat2.y.label;
plot2.layout.yaxis.type = mat2.y.scale;

textual_output.type = 'info';
textual_output.msg = strcat('Fibers with non-0 evidence:', {' '}, ...
                        num2str(json.out.stats.non0_tracks), ...
                        ' out of', {' '}, ...
                        num2str(json.out.stats.input_tracks), ...
                        ' total tracks');
textual_output.msg = textual_output.msg{1};

product_json = {plot1, plot2, textual_output};
savejson('brainlife', product_json, 'product.json');

system('echo 0 > finished');
disp('all done')

end
