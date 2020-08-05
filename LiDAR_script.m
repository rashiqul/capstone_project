clc
clear
disp('New Format Vertical Angle Finder')

 

% data will be formatted as:

% angle , angle, angle....

% distance, disatance, distance....

 

 file = "ANGLES3.csv";

 M = readmatrix(file);

 [rows, cols] = size(M);

 angle_rows = 1:2:rows;

 distance_rows = 2:2:rows;

%  usable_sweep_number = sum(nnz( M( distance_rows,: ))==104 );

 corrected_distances = zeros( 0 , cols );
 corrected_angles      = zeros( 0 , cols );


 current_sweep_index = 1;
 sum = 0; number_of_results = 0;
 shit = zeros(44,1);
 for r = distance_rows
      if ( nnz( M(r,:) ) == 104 )
            corrected_angles(current_sweep_index,:) = M( (r-1), :);
            corrected_distances(current_sweep_index,:) = M(r, :);
%                         plot(corrected_angles(current_sweep_index,:),corrected_distances(current_sweep_index,:))
%                         hold on
            P = polyfit( corrected_angles(current_sweep_index,:) , corrected_distances(current_sweep_index,:) , 4);
                % gets coefficients of line of best fit (4th order)
            D = polyder(P); % gets coefficients of derivative of line of best fit (4th order)
%             roots(D)
            minimum_angle  = min( corrected_angles(current_sweep_index,:) ); % finds minimum angle present in each sweep
            maximum_angle = max( corrected_angles(current_sweep_index,:) ); % finds maximum angle present in each sweep
            test_angles = linspace( minimum_angle,maximum_angle,100000); % simply a domain to evaluate the polynomial over
            D_values = polyval(D,test_angles);
            Q = mean( test_angles( find(D_values>-1e-3 & D_values<1e-3) ) );
            shit(current_sweep_index) = Q;
                if (~isnan(Q))
                    sum = sum + Q;
                    number_of_results = number_of_results +1;
                end
                current_sweep_index = current_sweep_index +1; % MUST BE LAST IN IF STATEMENT
      end
 end

 % Would love some coffee right now

 vertical_angle = sum / number_of_results;

 % now I want the distance the LiDAR is from the ground

 numb2 = 0; sum2 = 0; tol = 0.01; %tolerance factor

 [rows2, cols2] = size(corrected_angles);

 for x = 1:rows2

     for y = 1:cols2

         if ( corrected_angles(x,y) < vertical_angle * (1+tol) && corrected_angles(x,y) > vertical_angle * (1-tol)   )

%              fprintf("%f\n",corrected_distances(x,y))

             sum2 = sum2 + corrected_distances(x,y);

             numb2 = numb2 + 1;

         end

     end

 end

 

vertical_distance = sum2/numb2;

fprintf("Vertical Angle = %.2f degrees\n", vertical_angle)

fprintf("Elevation of LiDAR = %.2f mm\n", vertical_distance)

 

% now to put this data into a 3D plottable form...

% First I'll convert all of the radial distances into elevations

[f,s] = find(corrected_angles < vertical_angle * (1+tol) & corrected_angles > vertical_angle * (1-tol) );

vertical_index = round(mean(s));

% fprintf("Verical Index = %d\n",vertical_index)

%Vertical index refers to the average location in the corrected_angles array

%where the values exceed the vertical_angle.

% the above is to find the index at which the angles exceed vertical_angle

% this is because angles>vertical are inside the perimeter of the sweep

% The data inside the perimeter will be disregarded for now, leaving a hole

heights               = zeros(rows2 , vertical_index);

radial_distances = zeros(rows2 , vertical_index);

 ANGLE_CORRECTION = 0; % degrees

      
 
for m = 1:rows2
     for n = 1:vertical_index
        alpha = vertical_angle + ANGLE_CORRECTION - corrected_angles(m,n);
        % if the ground plane appears skewed, the the vertical_angle and/or
        % alpha combo is probably to blame. I'm considering artificially
        % adjusting alpha by a degree or two.
        heights(m,n) = corrected_distances(m,n)*cosd(alpha);
       radial_distances(m,n) = corrected_distances(m,n)*sind(alpha);
     end
end
  % Now I'll assume each of the 44 remaining sweeps from the original 72
  % are spaced equidstant apart around a circle. This is obviously a crude
  % approximation but will improve drastically when the data contains fewer
  % zeros. rows2 contains the number of rows (sweeps) in the 'heights' array
  
  pizza = 270; % The angle I am saying we sweeped around the tower
  theta = 0:pizza/rows2:pizza; % in degrees, assuming equidistant sweeps
  x_cartesian = zeros(rows2, vertical_index); % 44 rows 85 columns currently
  y_cartesian = zeros(rows2, vertical_index);
  r = zeros(rows2,1);
    for m = 1:rows2
         for n = 1:vertical_index
              x_cartesian(m,n) = radial_distances(m,n)*cosd(theta(m));
              y_cartesian(m,n) = radial_distances(m,n)*sind(theta(m));
              r(m,n) = sqrt(x_cartesian(m,n)^2 + y_cartesian(m,n)^2);
              alpha2 = shit(m) - corrected_angles(m,n);
              heights2(m,n) = corrected_distances(m,n)*cosd(alpha2);
         end
    end
    
    % now to find some statistics to make the user happy
    stand_dev = zeros(1,rows2);
    for juggalo = 1:rows2
        stand_dev(juggalo) = std( heights(juggalo,:) );
    end
    avg_stand_dev = mean(stand_dev);  
    % standard deviation taken from average of standard deviation of every sweep
    fprintf("Standard deviation of elevations = %.2f mm\n", avg_stand_dev)
    average_elevation = mean(mean(heights)) - vertical_distance;
    fprintf("Average elevation = %.2f mm\n", average_elevation)
   
    % tenth of a foot test
    tenth_of_foot_mm = 25.4*1.2;
    passes_test = 1; % assuming terrain is flat. For loops below check for failure condition
     for m = 1:rows2
         for n = 1:vertical_index
             if( abs( (heights(m,n) - vertical_distance)) > tenth_of_foot_mm )
                 passes_test = 0; % if magnitude of difference between height of LiDAR
                 % and any point is greater than 1/10 feet, then test fails
                 break
             end
         end
     end
  
     if (passes_test)
         disp("The terrain PASSED the test")
     else
         disp("The terrain FAILED the test")
     end
     
     % drumroll plz
     % surf( x_cartesian , y_cartesian , vertical_distance-heights )
