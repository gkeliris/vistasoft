function [fgsegment keepFascicles] = dtiSegmentFiberWithNiftiRoi(fg, targetROIfile, targetROI2file, thresholdmm)

% Extracting streamlines terminating within a certain distance from ROIs (e.g. gray matter ROIs)
% 
% INPUT:
% fg: fg structure
% targetROI: the name of first ROI nifti file
% targetROI2: the name of second ROI nifti file
% thresholdmm: the distance threshold in mm; the streamlines with endpoint within the threshold will be selected.

% (C) Hiromasa Takemura, CiNet HHS, 2017

if notDefined('thresholdmm')
thresholdmm = 4;
end

% Load ROIs
roi1 = niftiRead(targetROIfile);
roi2 = niftiRead(targetROI2file);

% Define threshold in image space (assuming isotropic)
% Note that the threshold is squared (we keep using squared number in subsequent process)
threshold = (thresholdmm./(roi1.pixdim(1)))^2;

% Get acpc to image transformation matrix
acpc2img = inv(roi1.qto_xyz);

% Transfer fg into image coordinate
fgImg = dtiXformFiberCoords(fg, acpc2img,'img');
%% Select fibers within a certain distance from each ROIs
fprintf('Segmenting tracts from Connectome ...\n')

voffiberlength = length(fgImg.fibers);
% Extract ACPC coordinate of dorsal and ventral VOF endpoint
for kk = 1:voffiberlength
    fibercoordinate = cell2mat(fgImg.fibers(kk));
    fiberlength = size(fibercoordinate);
        firstfiberend(kk,1) = fibercoordinate(1,1);
        firstfiberend(kk,2) = fibercoordinate(2,1);
        firstfiberend(kk,3) = fibercoordinate(3,1);
        secondfiberend(kk,1) = fibercoordinate(1,fiberlength(2));
        secondfiberend(kk,2) = fibercoordinate(2,fiberlength(2));
        secondfiberend(kk,3) = fibercoordinate(3,fiberlength(2));
        
    clear fibercoordinate fiberlength
end

%% Extract coordinates of ROIs
[tcoords(:,1), tcoords(:,2), tcoords(:,3)]= ind2sub(size(roi1.data), find(roi1.data));
[t2coords(:,1), t2coords(:,2), t2coords(:,3)]= ind2sub(size(roi2.data), find(roi2.data));


% Chose streamlines in which one endpoint is closer to ROI1, and the other
% endpoint is close to ROI2
for kp = 1:voffiberlength
    [indices_ff(kp), bestSqDis_ff(kp)] = nearpoints(transpose(firstfiberend(kp,:)), transpose(tcoords));
    [indices_ss(kp), bestSqDis_ss(kp)] = nearpoints(transpose(secondfiberend(kp,:)),transpose(t2coords));
    [indices_fs(kp), bestSqDis_fs(kp)] = nearpoints(transpose(firstfiberend(kp,:)), transpose(t2coords));
    [indices_sf(kp), bestSqDis_sf(kp)] = nearpoints(transpose(secondfiberend(kp,:)),transpose(tcoords));
end


% Select fibers within the threshold, then create keepFascicles
% structure
fffiber = find(bestSqDis_ff <threshold);
ssfiber = find(bestSqDis_ss <threshold);
fsfiber = find(bestSqDis_fs <threshold);
sffiber = find(bestSqDis_sf <threshold);

ffssfiber  = intersect(fffiber,ssfiber); % First streamline endpoint is near ROI1, the another endpoint is near ROI2
dssdfiber = intersect(fsfiber,sffiber); % First streamline endpoint is near ROI2, the another endpoint is near ROI1
bothfiber = transpose(union(transpose(ffssfiber), transpose(dssdfiber),'rows'));
bothsize = size(bothfiber);

%% If the selected number of streamlines are non-zero, extract those streamlines
if bothsize(2)>0
    keepFascicles = zeros(voffiberlength,1);
    for ik = 1:length(bothfiber)
        keepFascicles(bothfiber(ik)) = 1;
    end
fgsegment = fgExtract(fg, logical(keepFascicles), 'keep');
else
fprintf('No streamlines satisfied criteria ...\n')
end
end

