-- CS4400: Introduction to Database Systems: Monday, March 3, 2025
-- Simple Airline Management System Course Project Mechanics [TEMPLATE] (v0)
-- Views, Functions & Stored Procedures

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'flight_tracking';
use flight_tracking;
-- -----------------------------------------------------------------------------
-- stored procedures and views
-- -----------------------------------------------------------------------------
/* Standard Procedure: If one or more of the necessary conditions for a procedure to
be executed is false, then simply have the procedure halt execution without changing
the database state. Do NOT display any error messages, etc. */

-- [_] supporting functions, views and stored procedures
-- -----------------------------------------------------------------------------
/* Helpful library capabilities to simplify the implementation of the required
views and procedures. */
-- -----------------------------------------------------------------------------
drop function if exists leg_time;
delimiter //
create function leg_time (ip_distance integer, ip_speed integer)
	returns time reads sql data
begin
	declare total_time decimal(10,2);
    declare hours, minutes integer default 0;
    set total_time = ip_distance / ip_speed;
    set hours = truncate(total_time, 0);
    set minutes = truncate((total_time - hours) * 60, 0);
    return maketime(hours, minutes, 0);
end //
delimiter ;

-- [1] add_airplane()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airplane.  A new airplane must be sponsored
by an existing airline, and must have a unique tail number for that airline.
username.  An airplane must also have a non-zero seat capacity and speed. An airplane
might also have other factors depending on it's type, like the model and the engine.  
Finally, an airplane must have a new and database-wide unique location
since it will be used to carry passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airplane;
delimiter //
create procedure add_airplane (in ip_airlineID varchar(50), in ip_tail_num varchar(50),
	in ip_seat_capacity integer, in ip_speed integer, in ip_locationID varchar(50),
    in ip_plane_type varchar(100), in ip_maintenanced boolean, in ip_model varchar(50),
    in ip_neo boolean)
sp_main: begin
	if ip_airlineID is null or ip_tail_num is null or ip_seat_capacity is null or ip_speed is null
    then leave sp_main;
    end if;
	if
		ip_airlineID in (select airlineID from airline) and
        (ip_airlineID, ip_tail_num) not in (select airlineID, tail_num from airplane) and
        ip_locationID not in (select locationID from location) and
        ip_seat_capacity > 0 and
        ip_speed > 0 and
        ((ip_plane_type = 'Airbus' and ip_neo in (0, 1) and ip_model is null and ip_maintenanced is null) or
			(ip_plane_type = 'Boeing' and ip_maintenanced in (0,1) and ip_neo is null and ip_model is not null) or
			(ip_plane_type is null)) 
    then
        insert into location (locationID)
			values (ip_locationID);
		insert into airplane (airlineID, tail_num, seat_capacity, speed, locationID, plane_type, maintenanced, model, neo) 
			values (ip_airlineID, ip_tail_num, ip_seat_capacity, ip_speed, ip_locationID, ip_plane_type, ip_maintenanced, ip_model, ip_neo);
    end if;
end //
DELIMITER ;


-- [2] add_airport()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airport.  A new airport must have a unique
identifier along with a new and database-wide unique location if it will be used
to support airplane takeoffs and landings.  An airport may have a longer, more
descriptive name.  An airport must also have a city, state, and country designation. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airport;
delimiter //
create procedure add_airport (in ip_airportID char(3), in ip_airport_name varchar(200),
    in ip_city varchar(100), in ip_state varchar(100), in ip_country char(3), in ip_locationID varchar(50))
sp_main: begin
	if ip_airportID is null or ip_city is null or ip_state is null or ip_country is null
    then leave sp_main;
    end if;
	if
		(select count(*) from location where locationID = ip_locationID) = 0 and
		(select count(*) from airport where airportID = ip_airportID) = 0
    then
		insert into location (locationID)
		values (ip_locationID);
		insert into airport (airportID, airport_name, city, state, country, locationID)
		values (ip_airportID, ip_airport_name, ip_city, ip_state, ip_country, ip_locationID);
	end if;
end //
delimiter ;

-- [3] add_person()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new person.  A new person must reference a unique
identifier along with a database-wide unique location used to determine where the
person is currently located: either at an airport, or on an airplane, at any given
time.  A person must have a first name, and might also have a last name.

A person can hold a pilot role or a passenger role (exclusively).  As a pilot,
a person must have a tax identifier to receive pay, and an experience level.  As a
passenger, a person will have some amount of frequent flyer miles, along with a
certain amount of funds needed to purchase tickets for flights. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_person;
delimiter //
create procedure add_person (in ip_personID varchar(50), in ip_first_name varchar(100),
    in ip_last_name varchar(100), in ip_locationID varchar(50), in ip_taxID varchar(50),
    in ip_experience integer, in ip_miles integer, in ip_funds integer)
sp_main: begin
	if ip_personID is null or ip_first_name is null or ip_locationID is null
    then leave sp_main;
    end if;
	if
		(select count(*) from location where locationID = ip_locationID) > 0 and
		(select count(*) from person where personID = ip_personID) = 0 and
		((ip_miles is not null and ip_funds is not null and ip_taxID is null and ip_experience is null) or (ip_taxID is not null and ip_experience is not null and ip_miles is null and ip_funds is null))
	then
		insert into person (personID, first_name, last_name, locationID)
		values (ip_personID, ip_first_name, ip_last_name, ip_locationID);
		if
			ip_miles is not null and ip_funds is not null and ip_taxID is null and ip_experience is null
		then
			insert into passenger (personID, miles, funds)
			values (ip_personID, ip_miles, ip_funds);
        elseif
			ip_taxID is not null and ip_experience is not null and ip_miles is null and ip_funds is null
        then
			insert into pilot (personID, taxID, experience, commanding_flight)
			values (ip_personID, ip_taxID, ip_experience, null);
		end if;
	end if;
end //
delimiter ;

-- [4] grant_or_revoke_pilot_license()
-- -----------------------------------------------------------------------------
/* This stored procedure inverts the status of a pilot license.  If the license
doesn't exist, it must be created; and, if it aready exists, then it must be removed. */
-- -----------------------------------------------------------------------------
drop procedure if exists grant_or_revoke_pilot_license;
delimiter //
create procedure grant_or_revoke_pilot_license (in ip_personID varchar(50), in ip_license varchar(100))
sp_main: begin
	if ip_personID is null or ip_license is null
    then leave sp_main;
    end if;
	if
		(select count(*) from pilot where personID = ip_personID) > 0
    then
		if 
			(select count(*) from pilot_licenses where personID = ip_personID and license = ip_license)
		then
			delete from pilot_licenses where personID = ip_personID and license = ip_license;
        else
			insert into pilot_licenses (personID, license)
			values (ip_personID, ip_license);
        end if;
	end if;
end //
delimiter ;

-- [5] offer_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new flight.  The flight can be defined before
an airplane has been assigned for support, but it must have a valid route.  And
the airplane, if designated, must not be in use by another flight.  The flight
can be started at any valid location along the route except for the final stop,
and it will begin on the ground.  You must also include when the flight will
takeoff along with its cost. */
-- -----------------------------------------------------------------------------
drop procedure if exists offer_flight;
delimiter //
create procedure offer_flight (in ip_flightID varchar(50), in ip_routeID varchar(50),
    in ip_support_airline varchar(50), in ip_support_tail varchar(50), in ip_progress integer,
    in ip_next_time time, in ip_cost integer)
sp_main: begin
	if ip_flightID is null or ip_routeID is null
    then leave sp_main;
    end if;
	if
		(select count(*) from airplane where airlineID = ip_support_airline and tail_num = ip_support_tail) > 0 and
		(select count(*) from route where routeID = ip_routeID) > 0 and
		(select count(*) from route_path where routeID = ip_routeID) > ip_progress and 
		(select sequence from route_path where routeID = ip_routeID order by sequence desc limit 1) <> ip_progress and
		(select count(*) from flight where support_airline = ip_support_airline and support_tail = ip_support_tail) = 0
	then
		insert into flight (flightID, routeID, support_airline, support_tail, progress, airplane_status, next_time, cost)
		values (ip_flightID, ip_routeID, ip_support_airline, ip_support_tail, ip_progress, 'on_ground', ip_next_time, ip_cost);
    end if;
end //
delimiter ;

-- [6] flight_landing()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight landing at the next airport
along it's route.  The time for the flight should be moved one hour into the future
to allow for the flight to be checked, refueled, restocked, etc. for the next leg
of travel.  Also, the pilots of the flight should receive increased experience, and
the passengers should have their frequent flyer miles updated. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_landing;
delimiter //
create procedure flight_landing (in ip_flightID varchar(50))
sp_main: begin
	declare flight_miles int;
    declare route varchar(50);
    declare current_progress int;
    declare airplane_location varchar(50);
	if ip_flightID is null
    then leave sp_main;
    end if;
    select progress into current_progress from flight where flightID = ip_flightID;
    select routeID into route from flight where flightID = ip_flightID;
	select airplane.locationID into airplane_location from airplane join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail where flight.flightID = ip_flightID;    
	select leg.distance into flight_miles from leg join route_path on leg.legID = route_path.legID where route_path.routeID = route and route_path.sequence = current_progress;
    if
		(select count(*) from flight where flightID = ip_flightID and airplane_status = 'in_flight') > 0 
    then
		update pilot set experience = experience + 1 where commanding_flight = ip_flightID;
		update passenger join person on passenger.personID = person.personID set passenger.miles = passenger.miles + flight_miles where person.locationID = airplane_location;
		update flight set airplane_status = 'on_ground', next_time = addtime(next_time, '01:00:00' ) where flightID = ip_flightID;
	end if;
end //
delimiter ;

-- [7] flight_takeoff()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight taking off from its current
airport towards the next airport along it's route.  The time for the next leg of
the flight must be calculated based on the distance and the speed of the airplane.
And we must also ensure that Airbus and general planes have at least one pilot
assigned, while Boeing must have a minimum of two pilots. If the flight cannot take
off because of a pilot shortage, then the flight must be delayed for 30 minutes. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_takeoff;
delimiter //
create procedure flight_takeoff (in ip_flightID varchar(50))
sp_main: begin
	declare ip_plane_type varchar(100);
    declare flight_speed, num_pilots, distance, seconds, current_progress, max_progress, new_progress int;
	if ip_flightID is null
    then leave sp_main;
    end if;
    select progress into current_progress from flight where flightID = ip_flightID;
    select count(*) into max_progress from route_path where routeID = (select routeID from flight where flightID = ip_flightID);
    select count(*) into num_pilots from pilot where commanding_flight = ip_flightID;
    select airplane.plane_type, airplane.speed into ip_plane_type, flight_speed from airplane join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail where flight.flightID = ip_flightID;    
    if
		(select count(*) from flight where flightID = ip_flightID and airplane_status = 'on_ground') > 0 and
		current_progress < max_progress
    then
		set new_progress = current_progress + 1;
        select leg.distance into distance from leg join route_path on leg.legID = route_path.legID where route_path.routeID = (select routeID from flight where flightID = ip_flightID) and route_path.sequence = new_progress;
        
		if 
			((ip_plane_type in ('Airbus', 'general') and num_pilots >= 1) or (ip_plane_type = 'Boeing' and num_pilots >= 2))
		then 
			set seconds = round((distance/flight_speed) * 3600);
			update flight set progress = new_progress, airplane_status = 'in_flight', next_time = addtime(next_time, sec_to_time(seconds)) where flightID = ip_flightID;
        else
			update flight set next_time = addtime(next_time, '00:30:00') where flightID = ip_flightID;
        end if;
	end if;
end //
delimiter ;

-- [8] passengers_board()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting on a flight at
its current airport.  The passengers must be at the same airport as the flight,
and the flight must be heading towards that passenger's desired destination.
Also, each passenger must have enough funds to cover the flight.  Finally, there
must be enough seats to accommodate all boarding passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_board;
delimiter //
create procedure passengers_board (in ip_flightID varchar(50))
sp_main: begin
    declare current_progress, max_progress, new_progress int;
    declare current_airport char(3);
    declare airport_location, plane_location varchar(50);
    declare next_airport char(3);
    declare num_people, num_seats int;
    declare flight_cost float;
	if ip_flightID is null
    then leave sp_main;
    end if;
	select progress into current_progress from flight where flightID = ip_flightID;
    select count(*) into max_progress from route_path where routeID = (select routeID from flight where flightID = ip_flightID);
    if
	-- Ensure the flight exists
    -- Ensure that the flight is on the ground
    -- Ensure that the flight has further legs to be flown
		(select count(*) from flight where flightID = ip_flightID and airplane_status = 'on_ground') > 0 and
		current_progress < max_progress
	then
		select departure into current_airport from flight join route_path on flight.routeID = route_path.routeID join leg on route_path.legID = leg.legID where flightID = ip_flightID and sequence = current_progress + 1;
        select arrival into next_airport from flight join route_path on flight.routeID = route_path.routeID join leg on route_path.legID = leg.legID where flightID = ip_flightID and sequence = current_progress + 1;
		select cost into flight_cost from flight where flightID = ip_flightID;
        select locationID into plane_location from airplane where airlineID = (select support_airline from flight where flightID = ip_flightID) and tail_num = (select support_tail from flight where flightID = ip_flightID);
        select locationID into airport_location from airport where airportID = current_airport;
        select seat_capacity into num_seats from airplane where airlineID = (select support_airline from flight where flightID = ip_flightID) and tail_num = (select support_tail from flight where flightID = ip_flightID);
        select count(distinct(person.personID)) into num_people from person right join passenger on person.personID = passenger.personID right join passenger_vacations on passenger.personID = passenger_vacations.personID
			where person.locationID = airport_location and passenger_vacations.airportID = next_airport and (passenger.funds - flight_cost) > 0;
    -- Determine the number of passengers attempting to board the flight
    -- Use the following to check:
		-- The airport the airplane is currently located at
        -- The passengers are located at that airport
        -- The passenger's immediate next destination matches that of the flight
        -- The passenger has enough funds to afford the flight
        if 
			num_seats > num_people
		then
			with viable_passengers as (select passenger.personID from person right join passenger on person.personID = passenger.personID right join passenger_vacations on passenger.personID = passenger_vacations.personID
			where person.locationID = airport_location and passenger_vacations.airportID = next_airport and (passenger.funds - flight_cost) > 0)
				update person set locationID = plane_location where personID in (select personID from viable_passengers);
			with viable_passengers as (select passenger.personID from person right join passenger on person.personID = passenger.personID right join passenger_vacations on passenger.personID = passenger_vacations.personID
			where person.locationID = plane_location and passenger_vacations.airportID = next_airport and (passenger.funds - flight_cost) > 0)
				update passenger set funds = funds - flight_cost where personID in (select personID from viable_passengers);
	-- Check if there enough seats for all the passengers
		-- If not, do not add board any passengers
        -- If there are, board them and deduct their funds
        end if;
	end if;
end //
delimiter ;

-- [9] passengers_disembark()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting off of a flight
at its current airport.  The passengers must be on that flight, and the flight must
be located at the destination airport as referenced by the ticket. */
-- -----------------------------------------------------------------------------

drop procedure if exists passengers_disembark;
delimiter //
create procedure passengers_disembark (in ip_flightID varchar(50))
sp_main: begin
	declare plane_location, plane_airport_location varchar(50);
    declare airport_location char(3);
    declare current_progress int;
	if ip_flightID is null
    then leave sp_main;
    end if;
    select progress into current_progress from flight where flightID = ip_flightID;
    select locationID into plane_location from airplane where airlineID = (select support_airline from flight where flightID = ip_flightID) and tail_num = (select support_tail from flight where flightID = ip_flightID);
    select locationID into plane_airport_location from airport join leg on airport.airportID = leg.arrival where legID = (select legID from route_path join flight on route_path.routeID = flight.routeID where flightID = ip_flightID and sequence = current_progress);
	select airportID into airport_location from airport where locationID = plane_airport_location;
    
	-- Ensure the flight exists ensure that the flight is in the air
    if (select count(*) from flight where flightID = ip_flightID and airplane_status = 'on_ground') > 0
    then
		with viable_passengers as (select passenger.personID from person right join passenger on person.personID = passenger.personID join passenger_vacations on passenger.personID = passenger_vacations.personID where person.locationID = plane_location and passenger_vacations.sequence = 1 and passenger_vacations.airportID = airport_location)
			update person set locationID = plane_airport_location where personID in (select personID from viable_passengers);
            
		with viable_passengers as (select passenger.personID from person right join passenger on person.personID = passenger.personID join passenger_vacations on passenger.personID = passenger_vacations.personID where person.locationID = plane_airport_location and passenger_vacations.sequence = 1 and passenger_vacations.airportID = airport_location)
			delete from passenger_vacations where airportID = plane_airport_location and sequence = 1 and personID in (select personID from viable_passengers);
            
		with viable_passengers as (select passenger.personID from person right join passenger on person.personID = passenger.personID join passenger_vacations on passenger.personID = passenger_vacations.personID where person.locationID = plane_airport_location)
			update passenger_vacations set sequence = sequence - 1 where personID in (select personID from viable_passengers) and sequence > 1;
    -- Determine the list of passengers who are disembarking
	-- Use the following to check:
		-- Passengers must be on the plane supporting the flight
        -- Passenger has reached their immediate next destionation airport
        
	-- Move the appropriate passengers to the airport
    -- Update the vacation plans of the passengers
	end if;
end //
delimiter ;


-- [10] assign_pilot()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a pilot as part of the flight crew for a given
flight.  The pilot being assigned must have a license for that type of airplane,
and must be at the same location as the flight.  Also, a pilot can only support
one flight (i.e. one airplane) at a time.  The pilot must be assigned to the flight
and have their location updated for the appropriate airplane. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_pilot;
delimiter //
create procedure assign_pilot (in ip_flightID varchar(50), in ip_personID varchar(50))
sp_main: begin
    declare ip_plane_type, plane_airport_location, plane_location varchar(50);
    declare current_progress, max_progress int;
	if ip_flightID is null OR ip_personID is null
    then leave sp_main;
    end if;
    select locationID into plane_location from airplane where airlineID = (select support_airline from flight where flightID = ip_flightID) and tail_num = (select support_tail from flight where flightID = ip_flightID);
	select progress into current_progress from flight where flightID = ip_flightID;
    select locationID into plane_airport_location from airport join leg on airport.airportID = leg.departure where legID = (select legID from route_path join flight on route_path.routeID = flight.routeID where flightID = ip_flightID and sequence = current_progress + 1);
	select count(*) into max_progress from route_path where routeID = (select routeID from flight where flightID = ip_flightID);
	select airplane.plane_type into ip_plane_type from airplane join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail where flight.flightID = ip_flightID;

    if 
		(select count(*) from flight where flightID = ip_flightID and airplane_status = 'on_ground') > 0 and
		current_progress < max_progress and
        (select count(*) from pilot where personID = ip_personID and commanding_flight is null) > 0 and
        exists (select 1 from pilot_licenses where personID = ip_personID and license in (ip_plane_type, 'general')) and
       (select count(*) from person where personID = ip_personID and locationID = plane_airport_location) > 0 
    then
        update pilot set commanding_flight = ip_flightID where personID = ip_personID;
		update person set locationID = plane_location where personID = ip_personID;
    end if;
end //
delimiter ;


-- [11] recycle_crew()
-- -----------------------------------------------------------------------------
/* This stored procedure releases the assignments for a given flight crew.  The
flight must have ended, and all passengers must have disembarked. */
-- -----------------------------------------------------------------------------
drop procedure if exists recycle_crew;
delimiter //
create procedure recycle_crew (in ip_flightID varchar(50))
sp_main: begin
    declare plane_location, plane_airport_location varchar(50);
    declare passengers_on_board int;
    declare current_progress, max_progress int;
	if ip_flightID is null
    then leave sp_main;
    end if;
    select locationID into plane_location from airplane where airlineID = (select support_airline from flight where flightID = ip_flightID) and tail_num = (select support_tail from flight where flightID = ip_flightID);
	select progress into current_progress from flight where flightID = ip_flightID;
    select count(*) into passengers_on_board from person where locationID = plane_location and person.personID in (select passenger.personID from passenger);
	select locationID into plane_airport_location from airport join leg on airport.airportID = leg.arrival where legID = (select legID from route_path join flight on route_path.routeID = flight.routeID where flightID = ip_flightID and sequence = current_progress);
    select count(*) into max_progress from route_path where routeID = (select routeID from flight where flightID = ip_flightID);
	-- Ensure that the flight is on the ground
    if
		(select count(*) from flight where flightID = ip_flightID and airplane_status = 'on_ground') > 0 and
    -- Ensure that the flight does not have any more legs
		current_progress = max_progress and
    -- Ensure that the flight is empty of passengers
		passengers_on_board = 0
	then
		with viable_pilots as (select pilot.personID from person join pilot on person.personID = pilot.personID where locationID = plane_location)
		update pilot set commanding_flight = null where personID in (select * from viable_pilots);
		with viable_pilots as (select pilot.personID from person join pilot on person.personID = pilot.personID where locationID = plane_location)
        update person set locationID = plane_airport_location where personID in (select * from viable_pilots);
    -- Update assignements of all pilots
    -- Move all pilots to the airport the plane of the flight is located at
	end if;
end //
delimiter ;


-- [12] retire_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a flight that has ended from the system.  The
flight must be on the ground, and either be at the start its route, or at the
end of its route.  And the flight must be empty - no pilots or passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists retire_flight;
delimiter //
create procedure retire_flight (in ip_flightID varchar(50))
sp_main: begin
	declare max_progress int;
    declare current_location varchar(50);
	if ip_flightID is null
    then leave sp_main;
    end if;
    select max(sequence) into max_progress from route_path where routeID = (select routeID from flight where flightID = ip_flightID);
	if
    (select count(*) from flight where flightID = ip_flightID and airplane_status = 'on_ground') > 0 and
	(select progress from flight where flightID = ip_flightID) in (0, max_progress)
    then
		if 
        (select count(*) from person where locationID = (select locationID from flight where flightID = ip_flightID)) > 0
        then
			if 
				(select progress from flight where flightID = ip_flightID) = 0
            then
				select locationID into current_location from airport join leg on airport.airportID = leg.departure where legID = (select legID from route_path join flight on route_path.routeID = flight.routeID where flightID = ip_flightID and sequence = max_progress);
				update person join (select personID from person where locationID = (select locationID from flight where flightID = ip_flightID)) as viable_people on person.personID = viable_people.personID
					set person.locationID = current_location;
			else
				select locationID into current_location from airport join leg on airport.airportID = leg.departure where legID = (select legID from route_path join flight on route_path.routeID = flight.routeID where flightID = ip_flightID and sequence = 1);
				update person join (select personID from person where locationID = (select locationID from flight where flightID = ip_flightID)) as viable_people on person.personID = viable_people.personID
					set person.locationID = current_location;
			delete from flight where flightID = ip_flightID;
            end if;
		end if;
	end if;
end //
delimiter ;

-- [13] simulation_cycle()
-- -----------------------------------------------------------------------------
/* This stored procedure executes the next step in the simulation cycle.  The flight
with the smallest next time in chronological order must be identified and selected.
If multiple flights have the same time, then flights that are landing should be
preferred over flights that are taking off.  Similarly, flights with the lowest
identifier in alphabetical order should also be preferred.

If an airplane is in flight and waiting to land, then the flight should be allowed
to land, passengers allowed to disembark, and the time advanced by one hour until
the next takeoff to allow for preparations.

If an airplane is on the ground and waiting to takeoff, then the passengers should
be allowed to board, and the time should be advanced to represent when the airplane
will land at its next location based on the leg distance and airplane speed.

If an airplane is on the ground and has reached the end of its route, then the
flight crew should be recycled to allow rest, and the flight itself should be
retired from the system. */
-- -----------------------------------------------------------------------------
drop procedure if exists simulation_cycle;
DELIMITER //
create procedure simulation_cycle()
begin
    declare minTime time;
    declare minFlight varchar(50);
    declare prog int;
    declare maxSeq int;
    
    select min(next_time) into minTime from flight;
    if (select count(*) from flight where next_time = minTime) = 1 then
        select flightID into minFlight from flight where next_time = minTime;
    elseif (select count(*) from flight where next_time = minTime) > 1 then
        select flightID into minFlight from flight where next_time = minTime and airplane_status = 'in_flight' order by flightID asc limit 1;
    else
        select flightID into minFlight from flight where next_time = minTime order by flightID asc limit 1;
    end if;
    
    if (select airplane_status from flight where flightID = minFlight) = 'in_flight' then
        call flight_landing(minFlight);
        call passengers_disembark(minFlight);
		select MAX(sequence), MAX(progress) into maxSeq, prog from 
        route_path r join flight f on r.routeID = f.routeID
        where flightID = minFlight;
        
        if prog >= maxSeq then
            call recycle_crew(minFlight);
            call retire_flight(minFlight);
        end if;
    elseif (select airplane_status from flight where flightID = minFlight) = 'on_ground' then
        call passengers_board(minFlight);
        call flight_takeoff(minFlight);
    end if;

end //
DELIMITER ;


-- [14] flights_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently airborne are located. 
We need to display what airports these flights are departing from, what airports 
they are arriving at, the number of flights that are flying between the 
departure and arrival airport, the list of those flights (ordered by their 
flight IDs), the earliest and latest arrival times for the destinations and the 
list of planes (by their respective flight IDs) flying these flights. */
-- -----------------------------------------------------------------------------
create or replace view flights_in_the_air (departing_from, arriving_at, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as
select l.departure, l.arrival, count(*), group_concat(DISTINCT f.flightID ORDER BY f.flightID), min(f.next_time), max(f.next_time), group_concat(ap.locationID order by f.flightID) 
from flight f
join route_path rp on f.routeID = rp.routeID 
join leg l on rp.legID = l.legID and rp.sequence = f.progress
join airplane ap on f.support_tail = ap.tail_num and f.support_airline = ap.airlineID
where f.airplane_status = 'in_flight' 
group by l.departure, l.arrival;

-- [15] flights_on_the_ground()
-- ------------------------------------------------------------------------------
/* This view describes where flights that are currently on the ground are 
located. We need to display what airports these flights are departing from, how 
many flights are departing from each airport, the list of flights departing from 
each airport (ordered by their flight IDs), the earliest and latest arrival time 
amongst all of these flights at each airport, and the list of planes (by their 
respective flight IDs) that are departing from each airport.*/
-- ------------------------------------------------------------------------------
create or replace view flights_on_the_ground (departing_from, num_flights,
flight_list, earliest_arrival, latest_arrival, airplane_list) as 
select l.arrival, count(f.flightID), group_concat(DISTINCT f.flightID ORDER BY f.flightID), min(f.next_time), max(f.next_time), group_concat(ap.locationID) 
from flight f
join route_path rp on f.routeID = rp.routeID 
join leg l on rp.legID = l.legID and rp.sequence = f.progress
join airplane ap on f.support_tail = ap.tail_num and f.support_airline = ap.airlineID
where f.airplane_status = 'on_ground' 
group by l.arrival
union
select l.departure, count(f.flightID), group_concat(DISTINCT f.flightID ORDER BY f.flightID), min(f.next_time), max(f.next_time), group_concat(ap.locationID) 
from flight f
join route_path rp on f.routeID = rp.routeID 
join leg l on rp.legID = l.legID and rp.sequence = f.progress + 1
join airplane ap on f.support_tail = ap.tail_num and f.support_airline = ap.airlineID
where f.airplane_status = 'on_ground' 
group by l.departure;


-- [16] people_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently airborne are located. We 
need to display what airports these people are departing from, what airports 
they are arriving at, the list of planes (by the location id) flying these 
people, the list of flights these people are on (by flight ID), the earliest 
and latest arrival times of these people, the number of these people that are 
pilots, the number of these people that are passengers, the total number of 
people on the airplane, and the list of these people by their person id. */
-- -----------------------------------------------------------------------------
create or replace view people_in_the_air (departing_from, arriving_at, num_airplanes,
	airplane_list, flight_list, earliest_arrival, latest_arrival, num_pilots,
	num_passengers, joint_pilots_passengers, person_list) as
	select 
    a1.airportID as departing_from,
    a2.airportID as arriving_at,
    count(distinct a.tail_num) as num_airplanes,
    group_concat(distinct p.locationID) as airplane_list,
    group_concat(distinct f.flightID) as flight_list,
    min(next_time) as earliest_arrival,
    max(next_time) as latest_arrival,
    count(distinct pl.personID) as num_pilots,
    count(distinct ps.personID) as num_passengers,
    count(distinct pl.personID) + count(distinct ps.personID) as joint_pilots_passengers,
    group_concat(distinct p.personID) as person_list
	from 
    flight f
    left join airplane a on (f.support_airline = a.airlineID and f.support_tail = a.tail_num)
    left join person p on a.locationID = p.locationID
    left join pilot pl on p.personID = pl.personID
    left join passenger ps on p.personID = ps.personID
    left join route_path rp on rp.routeID = f.routeID and rp.sequence = f.progress
    join leg l on rp.legID = l.legID
    left join airport a1 on l.departure = a1.airportID
    left join airport a2 on l.arrival = a2.airportID
	where 
    f.airplane_status = 'in_flight'
	group by
    a1.airportID, a2.airportID;
    
-- [17] people_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently on the ground and in an 
airport are located. We need to display what airports these people are departing 
from by airport id, location id, and airport name, the city and state of these 
airports, the number of these people that are pilots, the number of these people 
that are passengers, the total number people at the airport, and the list of 
these people by their person id. */
-- -----------------------------------------------------------------------------
create or replace view people_on_the_ground (departing_from, airport, airport_name,
	city, state, country, num_pilots, num_passengers, joint_pilots_passengers, person_list) as
	select
    a.airportID as departing_from,
    a.locationID as airport,
    a.airport_name,
    a.city,
    a.state,
    a.country,
    count(distinct pl.taxID) as num_pilots,
    count(distinct ps.funds) as num_passengers,
    count(distinct pl.personID) + count(distinct ps.personID) as joint_pilots_passengers,
    group_concat(distinct p.personID) as person_list
	from person p left join passenger ps on p.personID = ps.personID
    left join pilot pl on p.personID = pl.personID
    right join airport a on p.locationID = a.locationID group by a.airportID having person_list is not null and airport is not null;

-- [18] route_summary()
-- -----------------------------------------------------------------------------
/* This view will give a summary of every route. This will include the routeID, 
the number of legs per route, the legs of the route in sequence, the total 
distance of the route, the number of flights on this route, the flightIDs of 
those flights by flight ID, and the sequence of airports visited by the route. */
-- -----------------------------------------------------------------------------
create or replace view route_summary (route, num_legs, leg_sequence, route_length,
	num_flights, flight_list, airport_sequence) as
select rp.routeID, count(distinct l.legID), group_CONCAT(distinct l.legID order by rp.sequence), 
(select sum(legmiles1.distance) 
     from (select distinct l2.legID, l2.distance 
           from leg l2 
           inner join route_path rp2 on l2.legID = rp2.legID 
           where rp2.routeID = rp.routeID)as legmiles1) as legmiles2,  count(distinct f.flightID), 
group_concat(distinct f.flightID order by f.flightID), 
group_concat(distinct l.departure, '->', l.arrival order by rp.sequence)
from route_path rp inner join leg l on rp.legID = l.legID
left join flight f on rp.routeID = f.routeID
group by rp.routeID;



-- [19] alternative_airports()
-- -----------------------------------------------------------------------------
/* This view displays airports that share the same city and state. It should 
specify the city, state, the number of airports shared, and the lists of the 
airport codes and airport names that are shared both by airport ID. */
-- -----------------------------------------------------------------------------
create or replace view alternative_airports (city, state, country, num_airports,
      airport_code_list, airport_name_list) as
select city, state, country, count(*), group_concat(airportID order by airportID), group_concat(airport_name order by airportID)
from airport
group by city, state, country having count(*) > 1;
