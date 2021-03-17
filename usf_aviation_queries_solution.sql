/*
1) In how many flights, planes departed with more than half of their full capacity in passengers in 2016?
*/

select fl.flight_id, count(*) cantidad, pl.capacity
from	tickets ti join 
		flights fl on fl.flight_id = ti.flight_id join
		planes pl on pl.plane_id = fl.plane_id
where year(fl.date) = 2016
group by fl.flight_id, pl.capacity
having count(*) >  (pl.capacity/2)
order by cantidad desc

/*
2) In how many flights, planes departed with less than 25% of their full capacity in passengers in 2017?
*/

select fl.flight_id, count(*) cantidad, pl.capacity
from	tickets ti join 
		flights fl on fl.flight_id = ti.flight_id join
		planes pl on pl.plane_id = fl.plane_id
where year(fl.date) = 2017
group by fl.flight_id, pl.capacity
having count(*) <  (pl.capacity/4)
order by cantidad desc

/*
3) Which route of flights generated the most and the least revenue in 2016?
*/
declare @table table (route_id int, [year] int, min_revenue decimal(10,2), max_revenue decimal(10,2), flights int) 
insert into @table
select	top 1 ro.route_id,
		year(fl.date) year,
		0 min_revenue,
		sum(ti.final_price) max_revenue,
		count(fl.flight_id) flights
from	tickets ti join
		flights fl on fl.flight_id = ti.flight_id join
		routes ro on ro.route_id = fl.route_id
where	year(fl.date) = 2016
group by fl.flight_id, ro.route_id, year(fl.date)
order by max_revenue desc

insert into @table
select	top 1 ro.route_id,
		year(fl.date) year,
		sum(ti.final_price) min_revenue,
		0 max_revenue,
		count(fl.flight_id) flights
from	tickets ti join
		flights fl on fl.flight_id = ti.flight_id join
		routes ro on ro.route_id = fl.route_id
where	year(fl.date) = 2016
group by fl.flight_id, ro.route_id, year(fl.date)
order by min_revenue asc

select * from @table

/*
4) The database does not contain any discounts since these were create after, but the managers want to know how much less money 
they would have made if they would have applied the discounts rates in the discounts table, having into 
account that:
4.1 The Elderly Discount applies to all the customers who, at the moment they purchase the ticket, are
at least 65 years old
4.2 The Student Discount applies to all the customers who, at the moment they purchase the ticket, are 
between 16 and 23 years old
*/
--4.1
go
select count(*) 'Student Discount count', sum(total_discount) total_discount
from
(
	select (final_price * (select percentage from discounts where name = 'Student Discount')) total_discount
	from tickets ti
	where customer_id in  
	(select customer_id from customers where datediff(year,birth_date,ti.purchase_date) between 16 and 23)
) a
go

--4.2
select count(*) 'Elderly Discount count', sum(total_discount) total_discount
from
(
	select (final_price * (select percentage from discounts where name = 'Elderly Discount')) total_discount
	from tickets ti
	where customer_id in  
	(select customer_id from customers where datediff(year,birth_date,ti.purchase_date) >= 65)
) a
go

/*
5) Estimate the monthly average ratio of tickets of registered passengers over not registered passengers 
in years 2016 and 2017.
*/
select	2016 year,	(	convert(decimal(10,2),(select count(*) from tickets where customer_id is not null /*and year(boarding_date) = 2016*/))
							/
						convert(decimal(10,2),(select count(*) from tickets where customer_id is null /*and year(boarding_date) = 2016*/))) as 'ratio' 
union
select	2017 year,	(	convert(decimal(10,2),(select count(*) from tickets where customer_id is not null and year(boarding_date) = 2017))
							/
						convert(decimal(10,2),(select count(*) from tickets where customer_id is null and year(boarding_date) = 2017))) as 'ratio' 


/*
6) For routes going from Tampa to Orlando, for each weekday, what is the most demanded route in terms of number 
of customers?
*/

select	row_number() over (order by sum(total) desc) orden,
		start_time_actual, 
		city_state,
		sum(total) total
from
(
	select start_time_actual, city_state, sum(total) total
	from
	(
		select	fl.flight_id, 
				start_time_actual, 
				(select name from cities_states where city_state_id = (select city_state_id_origin from routes where route_id = fl.route_id)) city_state, 
				count(*) total
		from flights fl join tickets ti
		on fl.flight_id = ti.flight_id
		where ( select name from cities_states where city_state_id = (select city_state_id_origin from routes where route_id = fl.route_id)) = 'Tampa'
		group by fl.flight_id, route_id, start_time_actual
	) a
	group by start_time_actual, city_state
) b
group by start_time_actual, city_state
order by total desc

/*
7) For routes going from Orlando to Tampa, for each weekday, what is the most demanded hour in terms 
of number of customers?
*/

select	row_number() over (order by sum(total) desc) orden,
		start_time_actual, 
		city_state,
		sum(total) total
from
(
	select start_time_actual, city_state, sum(total) total
	from
	(
		select	fl.flight_id, 
				start_time_actual, 
				(select name from cities_states where city_state_id = (select city_state_id_origin from routes where route_id = fl.route_id)) city_state, 
				count(*) total
		from flights fl join tickets ti
		on fl.flight_id = ti.flight_id
		where ( select name from cities_states where city_state_id = (select city_state_id_origin from routes where route_id = fl.route_id)) = 'Orlando'
		group by fl.flight_id, route_id, start_time_actual
	) a
	group by start_time_actual, city_state
) b
group by start_time_actual, city_state
order by total desc



/*
8) Knowing that at least 25% of the capacity of the full passenger capacity of the planes is 
necessary to justify the departure of the flight, the managers would like to know which flights 
should not have departed in the year 2017?
*/
	select	ROW_NUMBER() over (order by sum(tickets) desc) orden,
			year,
			flight_id, 
			sum(tickets) tickets,
			case when sum(tickets) > (select capacity * .25 from planes where plane_id = a.plane_id) then 'YES' else 'NO' end as 'justify'
	from
	(
		select	year(date)	 year, 
				fl.flight_id,
				fl.plane_id,
				count(*)	tickets
		from flights fl join tickets ti
		on fl.flight_id = ti.flight_id
		where year(date) = 2017
		group by fl.flight_id, fl.plane_id, year(date)
	) a
	group by flight_id, plane_id, year
	order by orden asc












--13) Assuming that 3 wagons are assigned to each train in every travel, what is the lowest and highest monthly utilization of the wagons in 2016? In what months?(in terms of seats occupied)

	select	ROW_NUMBER() over (order by sum(tickets) desc) orden,
			year,
			month, 
			sum(tickets) tickets,
			case	when ROW_NUMBER() over (order by sum(tickets) desc) = 1 then 'HIGHEST' 
					when ROW_NUMBER() over (order by sum(tickets) desc) = 12 then 'LOWEST'
					end as 'position'
	from
	(
		select	year(date)  year,
				right(convert(varchar(50), 100 + month(date)),2) +' - ' +  datename(month,date) month, 
				count(*)	tickets
		from flights fl join tickets ti
		on fl.flight_id = ti.flight_id
		where year(date) = 2017
		group by year(date), right(convert(varchar(50), 100 + month(date)),2) +' - ' +  datename(month,date) 
	) a
	group by year, month
	order by orden asc





--14) Assuming that 3 wagons are assigned to each train in every travel, what is the lowest and highest monthly utilization of the wagons in 2017? In what months?(in terms of seats occupied)

	select	ROW_NUMBER() over (order by sum(total) desc) orden,
			year,
			month, 
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case	when ROW_NUMBER() over (order by sum(total) desc) = 1 then 'HIGHEST' 
					when ROW_NUMBER() over (order by sum(total) desc) = 12 then 'LOWEST'
					end as 'position'
	from
	(
		select	year(date)  year,
				right(convert(varchar(50), 100 + month(date)),2) +' - ' +  datename(month,date) month, 
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr join tickets ti
		on tr.travel_id = ti.travel_id
		where year(date) = 2017
		group by year(date), right(convert(varchar(50), 100 + month(date)),2) +' - ' +  datename(month,date) 
		union
		select	year(date)  year,
				right(convert(varchar(50), 100 + month(date)),2) +' - ' +  datename(month,date) month, 
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr join passes_travels pt
		on tr.travel_id = pt.travel_id
		where year(date) = 2017
		group by year(date), right(convert(varchar(50), 100 + month(date)),2) +' - ' +  datename(month,date) 
	) a
	group by year, month
	order by orden asc

--15) Assuming that the breakeven point is 25 customers per travel, how many monthly travels should have been cancelled in 2016?

	select	ROW_NUMBER() over (order by sum(total) desc) orden,
			year,
			travel_id, 
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case when sum(total) >= 25 then 'OK' else 'CANCEL' end as 'justify'
	from
	(
		select	year(date)	 year, 
				tr.travel_id, 
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr join tickets ti
		on tr.travel_id = ti.travel_id
		where year(date) = 2016
		group by tr.travel_id, year(date)
		union
		select	year(date)  year,
				tr.travel_id, 
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr join passes_travels pt
		on tr.travel_id = pt.travel_id
		where year(date) = 2016
		group by tr.travel_id, year(date)
	) a
	group by travel_id, year
	order by orden asc


--16) Assuming that the breakeven point is 25 customers per travel, how many monthly travels should have been cancelled in 2017?

	select	ROW_NUMBER() over (order by sum(total) desc) orden,
			year,
			travel_id, 
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case when sum(total) >= 25 then 'OK' else 'CANCEL' end as 'justify'
	from
	(
		select	year(date)	 year, 
				tr.travel_id, 
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr join tickets ti
		on tr.travel_id = ti.travel_id
		where year(date) = 2017
		group by tr.travel_id, year(date)
		union
		select	year(date)  year,
				tr.travel_id, 
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr join passes_travels pt
		on tr.travel_id = pt.travel_id
		where year(date) = 2017
		group by tr.travel_id, year(date)
	) a
	group by travel_id, year
	order by orden asc


--17) What are the three employees that have sold the most passes in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				em.employee_id,
				(select first_name + ' ' + last_name from employees where employee_id = em.employee_id) name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) in (1,2,3) then 'TOP 3' else null end position
		from passes pa join employees em
		on pa.employee_id = em.employee_id
		where year(purchase_date) = 2016
		group by year(purchase_date), em.employee_id
		order by total desc

--18) What are the three employees that have sold the most passes in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				em.employee_id,
				(select first_name + ' ' + last_name from employees where employee_id = em.employee_id) name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) in (1,2,3) then 'TOP 3' else null end position
		from passes pa join employees em
		on pa.employee_id = em.employee_id
		where year(purchase_date) = 2017
		group by year(purchase_date), em.employee_id
		order by total desc

--19) What are the three employees that have sold the most tickets in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				em.employee_id,
				(select first_name + ' ' + last_name from employees where employee_id = em.employee_id) name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) in (1,2,3) then 'TOP 3' else null end position
		from tickets ti join employees em
		on ti.employee_id = em.employee_id
		where year(purchase_date) = 2016
		group by year(purchase_date), em.employee_id
		order by total desc

--20) What are the three employees that have sold the most tickets in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				em.employee_id,
				(select first_name + ' ' + last_name from employees where employee_id = em.employee_id) name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) in (1,2,3) then 'TOP 3' else null end position
		from tickets ti join employees em
		on ti.employee_id = em.employee_id
		where year(purchase_date) = 2017
		group by year(purchase_date), em.employee_id
		order by total desc

--21) What is the most sold cabin type in tickets in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				ct.cabin_type_id,
				(select name from cabin_types where cabin_type_id = ct.cabin_type_id) cabin_type_name,
				count(*)	total
		from tickets ti join cabin_types ct
		on ti.cabin_type_id = ct.cabin_type_id
		where year(purchase_date) = 2016
		group by year(purchase_date), ct.cabin_type_id
		order by total desc

--22) What is the most sold cabin type in tickets in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				ct.cabin_type_id,
				(select name from cabin_types where cabin_type_id = ct.cabin_type_id) cabin_type_name,
				count(*)	total
		from tickets ti join cabin_types ct
		on ti.cabin_type_id = ct.cabin_type_id
		where year(purchase_date) = 2017
		group by year(purchase_date), ct.cabin_type_id
		order by total desc

--23) What is the most sold cabin type in passes in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				ct.cabin_type_id,
				(select name from cabin_types where cabin_type_id = ct.cabin_type_id) cabin_type_name,
				count(*)	total
		from passes pa join cabin_types ct
		on pa.cabin_type_id = ct.cabin_type_id
		where year(purchase_date) = 2016
		group by year(purchase_date), ct.cabin_type_id
		order by total desc

--24) What is the most sold cabin type in passes in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				ct.cabin_type_id,
				(select name from cabin_types where cabin_type_id = ct.cabin_type_id) cabin_type_name,
				count(*)	total
		from passes pa join cabin_types ct
		on pa.cabin_type_id = ct.cabin_type_id
		where year(purchase_date) = 2017
		group by year(purchase_date), ct.cabin_type_id
		order by total desc

--25) What is the purchase location in which most tickets were sold in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				lo.location_id,
				(select name from locations where location_id = lo.location_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from tickets ti join locations lo
		on ti.purchase_location_id = lo.location_id
		where year(purchase_date) = 2016
		group by year(purchase_date), lo.location_id
		order by total desc

--26) What is the purchase location in which most tickets were sold in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				lo.location_id,
				(select name from locations where location_id = lo.location_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from tickets ti join locations lo
		on ti.purchase_location_id = lo.location_id
		where year(purchase_date) = 2017
		group by year(purchase_date), lo.location_id
		order by total desc

--27) What is the purchase location in which most passes were sold in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				lo.location_id,
				(select name from locations where location_id = lo.location_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from passes pa join locations lo
		on pa.purchase_location_id = lo.location_id
		where year(purchase_date) = 2016
		group by year(purchase_date), lo.location_id
		order by total desc

--28) What is the purchase location in which most passes were sold in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				lo.location_id,
				(select name from locations where location_id = lo.location_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from passes pa join locations lo
		on pa.purchase_location_id = lo.location_id
		where year(purchase_date) = 2017
		group by year(purchase_date), lo.location_id
		order by total desc

--29) What is the purchase location in which most cards were sold in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				lo.location_id,
				(select name from locations where location_id = lo.location_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from cards ca join locations lo
		on ca.purchase_location_id = lo.location_id
		where year(purchase_date) = 2016
		group by year(purchase_date), lo.location_id
		order by total desc

--30) What is the purchase location in which most cards were sold in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				lo.location_id,
				(select name from locations where location_id = lo.location_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from cards ca join locations lo
		on ca.purchase_location_id = lo.location_id
		where year(purchase_date) = 2017
		group by year(purchase_date), lo.location_id
		order by total desc

--31) How many travels did not have any customers in 2016?

	select	ROW_NUMBER() over (order by sum(total) asc) orden,
			year,
			travel_id, 
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case when sum(total) = 0 then 'YES' else null end as 'zero'
	from
	(
		select	year(date)	 year, 
				tr.travel_id, 
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr join tickets ti
		on tr.travel_id = ti.travel_id
		where year(date) = 2016
		group by tr.travel_id, year(date)
		union
		select	year(date)  year,
				tr.travel_id, 
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr join passes_travels pt
		on tr.travel_id = pt.travel_id
		where year(date) = 2016
		group by tr.travel_id, year(date)
	) a
	group by travel_id, year
	order by orden asc

--32) How many travels did not have any customers in 2017?

	select	ROW_NUMBER() over (order by sum(total) asc) orden,
			year,
			travel_id, 
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case when sum(total) = 0 then 'YES' else null end as 'zero'
	from
	(
		select	year(date)	 year, 
				tr.travel_id, 
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr join tickets ti
		on tr.travel_id = ti.travel_id
		where year(date) = 2017
		group by tr.travel_id, year(date)
		union
		select	year(date)  year,
				tr.travel_id, 
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr join passes_travels pt
		on tr.travel_id = pt.travel_id
		where year(date) = 2017
		group by tr.travel_id, year(date)
	) a
	group by travel_id, year
	order by orden asc


--33) What is the most used payment type in tickets in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				pt.payment_type_id,
				(select name from payment_types where payment_type_id = pt.payment_type_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from tickets ti join payment_types pt
		on ti.payment_type_id = pt.payment_type_id
		where year(purchase_date) = 2016
		group by year(purchase_date), pt.payment_type_id
		order by total desc

--34) What is the most used payment type in tickets in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				pt.payment_type_id,
				(select name from payment_types where payment_type_id = pt.payment_type_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from tickets ti join payment_types pt
		on ti.payment_type_id = pt.payment_type_id
		where year(purchase_date) = 2017
		group by year(purchase_date), pt.payment_type_id
		order by total desc

--35) What is the most used payment type in passes in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				pt.payment_type_id,
				(select name from payment_types where payment_type_id = pt.payment_type_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from passes pa join payment_types pt
		on pa.payment_type_id = pt.payment_type_id
		where year(purchase_date) = 2016
		group by year(purchase_date), pt.payment_type_id
		order by total desc

--36) What is the most used payment type in passes in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				pt.payment_type_id,
				(select name from payment_types where payment_type_id = pt.payment_type_id) location_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end as position
		from passes pa join payment_types pt
		on pa.payment_type_id = pt.payment_type_id
		where year(purchase_date) = 2017
		group by year(purchase_date), pt.payment_type_id
		order by total desc

--37) What is the date where the most revenue (sum of final price) in tickets was collected in 2016?

		select	ROW_NUMBER() over (order by sum(final_price) desc) orden,
				purchase_date,
				sum(final_price) revenue,
				count(*)	total,
				case when ROW_NUMBER() over (order by sum(final_price) desc) = 1 then 'TOP 1' else null end position
		from tickets ti 
		where year(purchase_date) = 2016
		group by purchase_date
		order by orden asc

--38) What is the date where the most revenue (sum of final price) in tickets was collected in 2017?

		select	ROW_NUMBER() over (order by sum(final_price) desc) orden,
				purchase_date,
				sum(final_price) revenue,
				count(*)	total,
				case when ROW_NUMBER() over (order by sum(final_price) desc) = 1 then 'TOP 1' else null end position
		from tickets ti 
		where year(purchase_date) = 2017
		group by purchase_date
		order by orden asc


--39) What is the date where the most revenue (sum of final price) in passes was collected in 2016?

		select	ROW_NUMBER() over (order by sum(final_price) desc) orden,
				purchase_date,
				sum(final_price) revenue,
				count(*)	total,
				case when ROW_NUMBER() over (order by sum(final_price) desc) = 1 then 'TOP 1' else null end position
		from passes pa 
		where year(purchase_date) = 2016
		group by purchase_date
		order by orden asc

--40) What is the date where the most revenue (sum of final price) in passes was collected in 2017?

		select	ROW_NUMBER() over (order by sum(final_price) desc) orden,
				purchase_date,
				sum(final_price) revenue,
				count(*)	total,
				case when ROW_NUMBER() over (order by sum(final_price) desc) = 1 then 'TOP 1' else null end position
		from passes pa 
		where year(purchase_date) = 2017
		group by purchase_date
		order by orden asc

--41) What is the hour of the day where the most tickets were sold in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				datepart(hour,purchase_time) purchase_time,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end position
		from tickets ti 
		where year(purchase_date) = 2016
		group by datepart(hour,purchase_time)
		order by orden asc

--42) What is the hour of the day where the most tickets were sold in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				datepart(hour,purchase_time) purchase_time,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end position
		from tickets ti 
		where year(purchase_date) = 2017
		group by datepart(hour,purchase_time)
		order by orden asc

--43) What is the hour of the day where the most passes were sold in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				datepart(hour,purchase_time) purchase_time,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end position
		from passes pa 
		where year(purchase_date) = 2016
		group by datepart(hour,purchase_time)
		order by orden asc

--44) What is the hour of the day where the most passes were sold in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				datepart(hour,purchase_time) purchase_time,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end position
		from passes pa 
		where year(purchase_date) = 2017
		group by datepart(hour,purchase_time)
		order by orden asc

--45) What is the hour of the day where the most cards were sold in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				datepart(hour,purchase_time) purchase_time,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end position
		from cards ca 
		where year(purchase_date) = 2016
		group by datepart(hour,purchase_time)
		order by orden asc

--46) What is the hour of the day where the most cards were sold in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				datepart(hour,purchase_time) purchase_time,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) = 1 then 'TOP 1' else null end position
		from cards ca 
		where year(purchase_date) = 2017
		group by datepart(hour,purchase_time)
		order by orden asc

--47) What are the three cities where the most customers live in?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) in (1,2,3) then 'TOP 3' else null end position
		from customers cu join cities_states cs
		on cu.city_state_id = cs.city_state_id
		group by cs.city_state_id, name
		order by orden asc

--48) What are the two cities where the most employees live in?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) in (1,2,3) then 'TOP 2' else null end position
		from employees em join cities_states cs
		on em.city_state_id = cs.city_state_id
		group by cs.city_state_id, name
		order by orden asc

--49) What are the six zip codes where the most customers live in?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) between 1 and 6 then 'TOP 6' else null end position
		from customers cu join zipcodes zc
		on cu.zipcode_id = zc.zipcode_id
		group by zc.zipcode_id, name
		order by orden asc

--50) What are the six zip codes where the most employees live in?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) between 1 and 6 then 'TOP 6' else null end position
		from employees em join zipcodes zc
		on em.zipcode_id = zc.zipcode_id
		group by zc.zipcode_id, name
		order by orden asc

--51) What are the three customers that bought the most tickets in 2016?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				(first_name + ' ' + last_name) customer_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) between 1 and 3 then 'TOP 3' else null end position
		from customers cu join tickets ti
		on cu.customer_id = ti.customer_id
		where year(ti.purchase_date) = 2016
		group by year(purchase_date), cu.customer_id, (cu.first_name + ' ' + cu.last_name)
		order by orden asc

--52) What are the three customers that bought the most tickets in 2017?

		select	ROW_NUMBER() over (order by count(*) desc) orden,
				year(purchase_date) year,
				(first_name + ' ' + last_name) customer_name,
				count(*)	total,
				case when ROW_NUMBER() over (order by count(*) desc) between 1 and 3 then 'TOP 3' else null end position
		from customers cu join tickets ti
		on cu.customer_id = ti.customer_id
		where year(ti.purchase_date) = 2017
		group by year(purchase_date), cu.customer_id, (cu.first_name + ' ' + cu.last_name)
		order by orden asc

--53) What is the most used route on weekends (saturday, sunday) in terms of customers travelling including passes and tickets in 2016?

	select	ROW_NUMBER() over (order by sum(total) desc) orden,
			year,
			weekday_name,
			route_id,
			start_time,
			city_state_origin_name,
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case	when ROW_NUMBER() over (order by sum(total) desc) = 1 then 'TOP 1' 
					end as 'position'
	from
	(
		select	year(date)  year,
				ro.route_id,
				ro.start_time,
				wd.name weekday_name,
				cs.name city_state_origin_name,
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr 
		join tickets ti
		on tr.travel_id = ti.travel_id
		join routes ro
		on ro.route_id = tr.route_id
		join cities_states cs
		on ro.city_state_id_origin = cs.city_state_id
		join weekdays wd
		on wd.weekday_id = ro.weekday_id
		where year(date) = 2016
		and wd.weekday_id in (6,7)
		group by year(date), ro.route_id, ro.start_time, cs.name, wd.name
		union
		select	year(date)  year,
				ro.route_id,
				ro.start_time,
				wd.name,
				cs.name city_state_origin_name,
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr 
		join passes_travels pa
		on tr.travel_id = pa.travel_id
		join routes ro
		on ro.route_id = tr.route_id
		join cities_states cs
		on ro.city_state_id_origin = cs.city_state_id
		join weekdays wd
		on wd.weekday_id = ro.weekday_id
		where year(date) = 2016
		and wd.weekday_id in (6,7)
		group by year(date), ro.route_id, ro.start_time, cs.name, wd.name
	) a
	group by year, weekday_name, route_id, start_time, city_state_origin_name
	order by orden asc

--54) What is the most used route on weekends (saturday, sunday) in terms of customers travelling including passes and tickets in 2017?

	select	ROW_NUMBER() over (order by sum(total) desc) orden,
			year,
			weekday_name,
			route_id,
			start_time,
			city_state_origin_name,
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case	when ROW_NUMBER() over (order by sum(total) desc) = 1 then 'TOP 1' 
					end as 'position'
	from
	(
		select	year(date)  year,
				ro.route_id,
				ro.start_time,
				wd.name weekday_name,
				cs.name city_state_origin_name,
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr 
		join tickets ti
		on tr.travel_id = ti.travel_id
		join routes ro
		on ro.route_id = tr.route_id
		join cities_states cs
		on ro.city_state_id_origin = cs.city_state_id
		join weekdays wd
		on wd.weekday_id = ro.weekday_id
		where year(date) = 2017
		and wd.weekday_id in (1,2,3,4,5)
		group by year(date), ro.route_id, ro.start_time, cs.name, wd.name
		union
		select	year(date)  year,
				ro.route_id,
				ro.start_time,
				wd.name,
				cs.name city_state_origin_name,
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr 
		join passes_travels pa
		on tr.travel_id = pa.travel_id
		join routes ro
		on ro.route_id = tr.route_id
		join cities_states cs
		on ro.city_state_id_origin = cs.city_state_id
		join weekdays wd
		on wd.weekday_id = ro.weekday_id
		where year(date) = 2017
		and wd.weekday_id in (6,7)
		group by year(date), ro.route_id, ro.start_time, cs.name, wd.name
	) a
	group by year, weekday_name, route_id, start_time, city_state_origin_name
	order by orden asc

--55) What is the most used route on weekdays (monday to friday) in terms of customers travelling including passes and tickets in 2016?

	select	ROW_NUMBER() over (order by sum(total) desc) orden,
			year,
			weekday_name,
			route_id,
			start_time,
			city_state_origin_name,
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case	when ROW_NUMBER() over (order by sum(total) desc) = 1 then 'TOP 1' 
					end as 'position'
	from
	(
		select	year(date)  year,
				ro.route_id,
				ro.start_time,
				wd.name weekday_name,
				cs.name city_state_origin_name,
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr 
		join tickets ti
		on tr.travel_id = ti.travel_id
		join routes ro
		on ro.route_id = tr.route_id
		join cities_states cs
		on ro.city_state_id_origin = cs.city_state_id
		join weekdays wd
		on wd.weekday_id = ro.weekday_id
		where year(date) = 2016
		and wd.weekday_id in (1,2,3,4,5)
		group by year(date), ro.route_id, ro.start_time, cs.name, wd.name
		union
		select	year(date)  year,
				ro.route_id,
				ro.start_time,
				wd.name,
				cs.name city_state_origin_name,
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr 
		join passes_travels pa
		on tr.travel_id = pa.travel_id
		join routes ro
		on ro.route_id = tr.route_id
		join cities_states cs
		on ro.city_state_id_origin = cs.city_state_id
		join weekdays wd
		on wd.weekday_id = ro.weekday_id
		where year(date) = 2016
		and wd.weekday_id in (1,2,3,4,5)
		group by year(date), ro.route_id, ro.start_time, cs.name, wd.name
	) a
	group by year, weekday_name, route_id, start_time, city_state_origin_name
	order by orden asc

--56) What is the most used route on weekdays (monday to friday) in terms of customers travelling including passes and tickets in 2017?

	select	ROW_NUMBER() over (order by sum(total) desc) orden,
			year,
			weekday_name,
			route_id,
			start_time,
			city_state_origin_name,
			sum(tickets) tickets, 
			sum(passes) passes, 
			sum(total) total,
			case	when ROW_NUMBER() over (order by sum(total) desc) = 1 then 'TOP 1' 
					end as 'position'
	from
	(
		select	year(date)  year,
				ro.route_id,
				ro.start_time,
				wd.name weekday_name,
				cs.name city_state_origin_name,
				count(*)	tickets,
				0			passes,
				count(*)	total
		from travels tr 
		join tickets ti
		on tr.travel_id = ti.travel_id
		join routes ro
		on ro.route_id = tr.route_id
		join cities_states cs
		on ro.city_state_id_origin = cs.city_state_id
		join weekdays wd
		on wd.weekday_id = ro.weekday_id
		where year(date) = 2017
		and wd.weekday_id in (1,2,3,4,5)
		group by year(date), ro.route_id, ro.start_time, cs.name, wd.name
		union
		select	year(date)  year,
				ro.route_id,
				ro.start_time,
				wd.name,
				cs.name city_state_origin_name,
				0			tickets,
				count(*)	passes,
				count(*)	total
		from travels tr 
		join passes_travels pa
		on tr.travel_id = pa.travel_id
		join routes ro
		on ro.route_id = tr.route_id
		join cities_states cs
		on ro.city_state_id_origin = cs.city_state_id
		join weekdays wd
		on wd.weekday_id = ro.weekday_id
		where year(date) = 2017
		and wd.weekday_id in (1,2,3,4,5)
		group by year(date), ro.route_id, ro.start_time, cs.name, wd.name
	) a
	group by year, weekday_name, route_id, start_time, city_state_origin_name
	order by orden asc

--Classify registered customers as follows:
--Young customers: 18-35 y.o.
--Adult customers: 36-64 y.o.
--Senior customers: 64+ y.o.
