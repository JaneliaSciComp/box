function    [I_label,candidate_obj_num] = ...
    predict_candidate(I_label,I_obj_prob,predict_pos,predict_ind,max_obj_num)


%%% if we have detected more candidates than the maximum allowed number
%%% we need to remove those with lower probability

%%%%%%
candidate_obj_num = max(max(I_label));
if( candidate_obj_num <= max_obj_num )
    return;
end
%%%  now we know some object have to be thrown away


%%% first make probability image from the predicted positions
G = ones(15,15);
G = G/sum(sum(G));
if( numel(predict_pos) > 0 )
    I_predict_prob = 0.5*ones(size(I_label));
    %% I_predict_prob(sub2ind(size(I_label),predict_pos(:,1),predict_pos(:,
    %% 2))) = 1; - old, delete
    for i=1:predict_ind(length(predict_ind)),
        if (numel(find(predict_ind==i)))
            I_predict_prob = mark_square_object(predict_pos(find(predict_ind==i),2),...
                predict_pos(find(predict_ind==i),1),1,I_predict_prob,3);
        else
            I_predict_prob = mark_square_object(0,0,1,I_predict_prob,3);
        end
    end
    %% I_predict_prob = conv2(I_predict_prob,G,'same');
    I_obj_prob = I_obj_prob .* I_predict_prob;
end

%%% set for each object the maximum probability
for i=1:candidate_obj_num,
    ind = find(I_label==i);
    I_obj_prob(ind) = max(I_obj_prob(ind)) + ((i/candidate_obj_num)/1000);
end
%%% leave only high prob objects
prob_values = unique(I_obj_prob(:));
cut_off_value = prob_values(length(prob_values)-max_obj_num+1);
remove_ind = find(I_obj_prob < cut_off_value);
I_label(remove_ind) = 0;
I_label = bwlabel(I_label);


