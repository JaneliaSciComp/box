
function [I_label, I_obj_prob] = ...
    candidate_objects(I_curr,I_bg,I_occlud,I_bg_top,I_bg_bottom)

%%%% detect condidate objects by bg subtraction
%%%% I_label        - the object label at each pixel (0 is bg)
%%%% I_obj_prob     - the probability for each pixel to be an object

se1 = strel('disk',1);
se2 = strel('disk',2);

I_obj_prob = zeros(size(I_occlud));

I_curr_gray = double((I_curr));
I_fg = uint8(abs(I_curr_gray - double(I_bg)));

%%%% give lower probablity to objects in occluded regions
%I_fg = immultiply(I_fg,I_occlud);
%I_fg_bw = im2bw(uint8(I_fg), graythresh(I_fg));
%I_fg_bw = im2bw(uint8(I_fg), 0.2);

%I_fg_top = I_curr_gray > I_bg_top;
I_fg_bottom = I_curr_gray < I_bg_bottom;
%I_fg_bw = (I_fg_top | I_fg_bottom);
%I_fg_bw = immultiply(I_fg_bw,I_occlud);
I_fg_bw = immultiply(I_fg_bottom,I_occlud); % only use bottom difference for Olypiad videos
% figure; subplot(3,1,1); imagesc(I_fg_bottom); 
% subplot(3,1,2); imagesc(I_occlud); 
% subplot(3,1,3); imagesc(I_fg_bw); pause
%%%% remove too small objects by morphological cleaning and then
%%%% enlarge objects slightly
%%%% This turned out to kill true objects
%I_fg_bw = ~imopen(imclose(~I_fg_bw,se1),se2);   
%% take median of each window (throws away dot objects
I_fg_bw = ordfilt2(I_fg_bw,5,ones(3,3));
I_fg_bw = ordfilt2(I_fg_bw,5,ones(3,3));
I_fg_bw = ordfilt2(I_fg_bw,5,ones(3,3));
%% enlarge objects by taking max of each window
%I_fg_bw = ordfilt2(I_fg_bw,9,ones(3,3));

%%%% label detected fg objects
I_label = bwlabel(I_fg_bw);

%%%% estimate probability of each object (max probability)
I_prob = double(immultiply(I_fg,I_fg_bw))/256;
I_obj_prob = zeros(size(I_prob));
obj_num = max(max(I_label));
for i=1:obj_num,
    %% Perturb a little the prob value so that we do not get 
    %% objects with exactly the same probability
    ind = find(I_label==i);
%    I_obj_prob(ind) = max(I_prob(ind)) + (i/obj_num)/256;
    I_obj_prob(ind) = max(I_prob(ind));
end
    

    
    




