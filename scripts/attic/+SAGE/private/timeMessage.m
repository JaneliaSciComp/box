function msg = timeMessage(remainingSecs)
    if remainingSecs > 7200
        msg = ['more than ' num2str(floor((remainingSecs + 1800) / 3600)) ' hours'];
    elseif remainingSecs > 3600
        msg = 'more than an hour';
    elseif remainingSecs > 90
        msg = ['about ' num2str(floor((remainingSecs + 30)/60)) ' minutes'];
    elseif remainingSecs > 60
        msg = 'about a minute';
    else
        msg = [num2str(ceil(remainingSecs)) ' seconds'];
    end
end
