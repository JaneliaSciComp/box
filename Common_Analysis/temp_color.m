function c = temp_color(t)
    if t >= 25.0
        % Warm red
        c = [1 0.3 0.3];
    else
        % Cool blue
        c = [0.3 0.3 1];
    end
end
