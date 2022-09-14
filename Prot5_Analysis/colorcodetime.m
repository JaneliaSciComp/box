if ((73000 < datetime) && (datetime < 90000)) || ...
        ((123000 < datetime) && (datetime < 140000))
    controls(exp).hour = 'first';
    controls(exp).marker = 's';
    controls(exp).color = [1 0 0]; % red
end

if ((90000 <= datetime) && (datetime < 100000)) || ...
        ((140000 <= datetime) && (datetime < 150000))
    controls(exp).hour = 'second';
    controls(exp).marker = 'o';
    controls(exp).color = [0 0.3922 0]; %dark green
end

if ((100000 <= datetime) && (datetime < 110000)) || ...
        ((150000 <= datetime) && (datetime < 160000))
    controls(exp).hour = 'third';
    controls(exp).marker = '*';
    controls(exp).color =[0 0 1]; %blue
end

if ((110000 <= datetime) && (datetime < 123000)) || ...
        ((160000 <= datetime) && (datetime < 170000))
    controls(exp).hour = 'fourth';
    controls(exp).marker = 'x';
    controls(exp).color = [104 34 139]/255; %dark purple
end
