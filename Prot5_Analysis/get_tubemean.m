function tubemean = get_tubemean(data,seq)

i = 1;
for tube = data.tubes
    tmp(i,:) = data.analysis_results(tube).(seq).cum_dir_index_peak;
end

tubemean = mean(tmp,1);
