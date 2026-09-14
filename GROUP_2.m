%% LEAF IMAGE-PROCESSING ASSIGNMENT
clear; 
clc; 
close all;

inputFolder = 'C:\Users\DELL\Desktop\GROUP_13_PICKED_LEAVES';
outputFolder = fullfile(fileparts(mfilename('fullpath')), 'GROUP_13_Leaf_Image_Processing_Results');
if ~exist(outputFolder, 'dir'), mkdir(outputFolder);
end

fileNames = {'Leaf 1.jpeg','Leaf 2.jpeg','Leaf 3.jpeg','leaf 4.jpeg', ...
    'leaf 5.jpeg','leaf 6.jpeg','leaf 7.jpeg','leaf 8.jpeg','leaf 9.jpeg', ...
    'leaf 10.jpeg','leaf 11.jpeg','leaf 12.jpeg','leaf 13.jpeg','leaf 14.jpeg', ...
    'leaf 15.jpeg','leaf 16.jpeg','leaf 17.jpeg','leaf 18.jpeg','leaf 19.jpeg','leaf 20.jpeg'};
commonNames = {'Mexican sunflower','Kale / cabbage-type mustard','Butterfly bush / Buddleja', ...
    'Grewia / raisin bush','Common bean','Coffee','Jackfruit','Guava','Avocado', ...
    'Siamese cassia','Sweet potato','Maize / corn','Papaya','Eggplant / aubergine', ...
    'Cotton','Mulberry','Citrus (lemon or orange)','Hibiscus','Chamber bitter / stonebreaker','Lantana'};
scientificNames = {'Tithonia diversifolia','Brassica oleracea','Buddleja sp.', ...
    'Grewia sp.','Phaseolus vulgaris','Coffea arabica or Coffea canephora', ...
    'Artocarpus heterophyllus','Psidium guajava','Persea americana','Senna siamea', ...
    'Ipomoea batatas','Zea mays','Carica papaya','Solanum melongena', ...
    'Gossypium hirsutum','Morus alba','Citrus sp.','Hibiscus rosa-sinensis', ...
    'Phyllanthus amarus','Lantana camara'};

operationNames = {'01_resized_RGB','02_grayscale','03_red_channel','04_green_channel', ...
    '05_blue_channel','06_HSV_saturation','07_Lab_lightness','08_contrast_stretch', ...
    '09_adaptive_histogram_equalization','10_median_filter','11_gaussian_filter', ...
    '12_unsharp_masking','13_Sobel_edges','14_Canny_edges','15_Otsu_binary_mask', ...
    '16_adaptive_binary_mask','17_morphological_opening','18_filled_leaf_mask', ...
    '19_leaf_perimeter','20_distance_transform'};

leafData = struct([]);
summaryRows = table();

for k = 1:numel(fileNames)
    sourceFile = fullfile(inputFolder, fileNames{k});
    if ~isfile(sourceFile)
    end
    specimenFolder = outputFolder;
    filePrefix = sprintf('Leaf_%02d_', k);

    % Original image and standard size for comparable processing.
    rgbOriginal = imread(sourceFile);
    if size(rgbOriginal,3) == 1, rgbOriginal = repmat(rgbOriginal,1,1,3); 
    end
    % Operations we undertook on the different leaves that we picked.
    rgb = imresize(im2uint8(rgbOriginal), [600 NaN]);                        
    imwrite(rgb, fullfile(specimenFolder, [filePrefix '00_original_RGB.png']));
    imwrite(rgb, fullfile(specimenFolder, [filePrefix operationNames{1} '.png']));

    gray = rgb2gray(rgb);                                                       
    red = rgb(:,:,1);                                                           
    green = rgb(:,:,2);                                                         
    blue = rgb(:,:,3);                                                          
    hsvImage = rgb2hsv(rgb);
    saturation = hsvImage(:,:,2);                                               
    labImage = rgb2lab(rgb);
    lightness = mat2gray(labImage(:,:,1));                                      
    contrastStretched = imadjust(gray);                                        
    clahe = adapthisteq(gray, 'ClipLimit', 0.02);                               
    medianFiltered = medfilt2(gray, [5 5]);                                     
    gaussianFiltered = imgaussfilt(gray, 2);                                   
    sharpened = imsharpen(gaussianFiltered, 'Radius', 2, 'Amount', 1.2);       
    sobelEdges = edge(gaussianFiltered, 'sobel');                               
    cannyEdges = edge(gaussianFiltered, 'canny');                               

    % Green pixels make a practical leaf mask against the background.
    greenDominance = imsubtract(im2single(green), max(im2single(red),im2single(blue)));
    greenMask = greenDominance > 0.015 | saturation > graythresh(saturation);
    otsuMask = imbinarize(gaussianFiltered, graythresh(gaussianFiltered));      
   
    if nnz(otsuMask & greenMask) < nnz(~otsuMask & greenMask)
        otsuMask = ~otsuMask;
    end
    adaptiveMask = imbinarize(gaussianFiltered, 'adaptive', ...                
        'ForegroundPolarity', 'dark', 'Sensitivity', 0.45);
    if nnz(adaptiveMask & greenMask) < nnz(~adaptiveMask & greenMask)
        adaptiveMask = ~adaptiveMask;
    end
    openedMask = imopen(greenMask | otsuMask, strel('disk', 4));                
    filledMask = imfill(openedMask, 'holes');                                  
    filledMask = bwareafilt(filledMask, 1); 
    perimeter = bwperim(filledMask);                                            
    distanceMap = bwdist(~filledMask);                                         
    processed = {gray,red,green,blue,saturation,lightness,contrastStretched,clahe, ...
        medianFiltered,gaussianFiltered,sharpened,sobelEdges,cannyEdges,otsuMask, ...
        adaptiveMask,openedMask,filledMask,perimeter,mat2gray(distanceMap)};
    for n = 2:numel(operationNames)
        imwrite(processed{n-1}, fullfile(specimenFolder, [filePrefix operationNames{n} '.png']));
    end

    % Morphological and colour features for the structural array.
    props = regionprops(filledMask, 'Area','Perimeter','MajorAxisLength', ...
        'MinorAxisLength','Eccentricity','Solidity','Extent','Centroid','BoundingBox');
    if isempty(props), props = emptyProperties(); end
    stats = regionprops(filledMask, gray, 'MeanIntensity','MinIntensity','MaxIntensity');
    if isempty(stats), stats = struct('MeanIntensity',NaN,'MinIntensity',NaN,'MaxIntensity',NaN); end
    hue = hsvImage(:,:,1); sat = hsvImage(:,:,2); val = hsvImage(:,:,3);
    meanHSV = [mean(hue(filledMask),'omitnan'), mean(sat(filledMask),'omitnan'), ...
        mean(val(filledMask),'omitnan')];
    if ~any(filledMask,'all'), meanHSV = [NaN NaN NaN]; end

    leafData(end+1).leafNumber = k; %#ok<SAGROW>
    leafData(end).fileName = fileNames{k};
    leafData(end).commonName = commonNames{k};
    leafData(end).scientificName = scientificNames{k};
    leafData(end).sourceFile = sourceFile;
    leafData(end).resultFolder = specimenFolder;
    leafData(end).operations = operationNames;
    leafData(end).mask = filledMask;
    leafData(end).properties = props;
    leafData(end).intensityStatistics = stats;
    leafData(end).meanHSVWholeImage = meanHSV;

    thisRow = table(k, string(commonNames{k}), string(scientificNames{k}), ...
        props.Area, props.Perimeter, props.MajorAxisLength, ...
        props.MinorAxisLength, props.Eccentricity, props.Solidity, props.Extent, ...
        stats.MeanIntensity, meanHSV(1), meanHSV(2), meanHSV(3), ...
        'VariableNames', {'LeafNumber','CommonName','ScientificName','AreaPixels', ...
        'PerimeterPixels','MajorAxisPixels','MinorAxisPixels','Eccentricity', ...
        'Solidity','Extent','MeanGrayIntensity','MeanHue','MeanSaturation','MeanValue'});
    if isempty(summaryRows)
        summaryRows = thisRow;
    else
        summaryRows = [summaryRows; thisRow]; %#ok<AGROW>
    end

    % A labelled 4-by-5 panel demonstrates the operations for each leaf.
    makeMontage(processed, operationNames, k, commonNames{k}, scientificNames{k}, specimenFolder, filePrefix);
end

save(fullfile(outputFolder, 'leaf_structural_array.mat'), 'leafData', 'operationNames');
writetable(summaryRows, fullfile(outputFolder, 'leaf_feature_summary.csv'));
writeOperationGuide(fullfile(outputFolder, 'README_operations.txt'), operationNames);
fprintf('\nFinished. Results saved to:\n%s\n', outputFolder);

function p = emptyProperties()
p = struct('Area',NaN,'Perimeter',NaN,'MajorAxisLength',NaN,'MinorAxisLength',NaN, ...
    'Eccentricity',NaN,'Solidity',NaN,'Extent',NaN,'Centroid',[NaN NaN],'BoundingBox',[NaN NaN NaN NaN]);
end

function makeMontage(images, names, number, common, scientific, folder, filePrefix)
fig = figure('Visible','off','Color','w','Position',[100 100 1500 980]);
tiledlayout(4,5,'Padding','compact','TileSpacing','compact');
for q = 1:numel(images)
    nexttile; imshow(images{q},[]); title(strrep(names{q}, '_', ' '), 'FontSize', 8);
end
sgtitle(sprintf('Leaf %d: %s (%s) — 20 image-processing operations', number, common, scientific), ...
    'FontWeight','bold');
exportgraphics(fig, fullfile(folder, [filePrefix '20_operation_panel.png']), 'Resolution', 180);
close(fig);
end

function writeOperationGuide(path, names)
fid = fopen(path, 'w');
fprintf(fid, 'LEAF IMAGE-PROCESSING OPERATIONS\n\n');
for i = 1:numel(names)
    fprintf(fid, '%02d. %s\n', i, strrep(names{i}, '_', ' '));
end
fprintf(fid, ['\nAll files are saved in this one results folder. Each image filename starts with its leaf number,\n' ...
    'followed by its original image, operation images, a labelled panel, leaf_structural_array.mat,\n' ...
    'and leaf_feature_summary.csv.\n' ...
    ]);
fclose(fid);
end