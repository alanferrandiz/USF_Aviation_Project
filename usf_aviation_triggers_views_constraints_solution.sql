--TRIGGERS
/*
1) Create an AFTER trigger in the travels table for the INSERT, UPDATE events, that restricts 
insertion or modification in the date column for dates before the year 2016 and after the
year 2019
*/
if exists (	select 1 from sys.triggers where name = 'tr_tr01')
	drop trigger tr_tr01
go
create trigger tr_tr01 
on flights 
for insert, update
as
begin
set nocount on
if not exists (select date from inserted where year(date) < 2016 and year(date) > 2019) 
	begin
		raiserror ('Dates must be between years 2016 and 2019', 16, 1)
		rollback transaction
	end
end
go

--TEST
/*
insert into flights (flight_id, date, route_id, plane_id) 
values (999999, '2020-01-01',5,1)
*/

/*
2) Create an INSTEAD OF trigger in the wagons table for the INSERT, UPDATE, DELETE events, that restricts the input, 
modification or deletion of rows in the table and shows the message "Input, modification or deletion of rows not allowed"
*/
if exists (	select 1 from sys.triggers where name = 'tr_tr02')
	drop trigger tr_tr02
go
create trigger tr_tr02 
on planes 
instead of insert, update, delete
as
	begin
	set nocount on
	print 'WARNING: Input, modification or deletion of rows not allowed in the planes table'
	end
go

--TEST
/*
insert into planes (plane_id) 
values (99999)
*/


/*
3) Create an INSTEAD OF trigger in the tickets table for the UPDATE event, that restricts the 
update of values in the final_price column that are 20% higher or lower that the corresponding 
value for the combination of route and cabin type in the price column of the routes_cabin_types 
table. If the value does not meet the given requirement, then the operation will be cancelled.
*/

if exists (	select 1 from sys.triggers where name = 'tr_tr03')
	drop trigger tr_tr03
go
create trigger tr_tr03 
on tickets 
instead of update
as
begin
set nocount on
declare @final_table	table (ticket_id int, validated_price decimal (10,2))

	insert into @final_table
	select	i.ticket_id, 
			case	when i.final_price between rct.price * 0.80 and rct.price * 1.20 then i.final_price
					else rct.price 
			end
	from	inserted i join
			flights fl on fl.flight_id = i.flight_id join
			routes_cabin_types rct on rct.route_id = fl.route_id and rct.cabin_type_id = i.cabin_type_id

	declare	@errors int = 0
	select	@errors = count(*)
	from	inserted i join
			flights fl on fl.flight_id = i.flight_id join
			routes_cabin_types rct on rct.route_id = fl.route_id and rct.cabin_type_id = i.cabin_type_id
	where i.final_price not between rct.price * 0.80 and rct.price * 1.20  

	declare	@totalrows int = 0
	select @totalrows = count(*) from inserted i
	
	update ti
	set		final_price = ft.validated_price
	from	@final_table ft join tickets ti
	on		ft.ticket_id = ti.ticket_id

	if @errors > 0
	begin
		print 'WARNING: ' + convert(varchar(200),@errors) + ' rows out of ' 
				+ convert(varchar(200),@totalrows) + ' rows were not updated because they were ' +
				'either 20% lower or 20% higher than the original price'
	end
end
go

--TEST
/*
select * from tickets where ticket_id in (100, 101)
update tickets set final_price = 1400 where ticket_id in (100, 101)
*/

/*
4) Create an INSTEAD OF trigger in the customers table for the INSERT and UPDATE events, that 
restricts the input or update of values in the first_name column whose length is between the shortest 
and longest length of all the values in the table for the first_name column.
*/

if exists (	select 1 from sys.triggers where name = 'tr_tr04')
	drop trigger tr_tr04
go
create trigger tr_tr04
on customers 
instead of insert, update
as
begin
	set nocount on

	declare @final_table table (customer_id int, validated_first_name varchar(50))

	insert into @final_table
	select	cu.customer_id, i.first_name
	from	inserted i join
			customers cu on i.customer_id = cu.customer_id
	where len(i.first_name) between 
	(select top 1 len(first_name) max_len from customers order by max_len asc) 
	and 
	(select top 1 len(first_name) max_len from customers order by max_len desc) 

	declare @errors int = 0
	select	@errors = count(*)
	from	inserted i join
			customers cu on i.customer_id = cu.customer_id
	where len(i.first_name) not between 
	(select top 1 len(first_name) max_len from customers order by max_len asc) 
	and 
	(select top 1 len(first_name) max_len from customers order by max_len desc) 

	declare	@totalrows int = 0
	select @totalrows = count(*) from inserted i

	update cu
	set		cu.first_name = ft.validated_first_name
	from	@final_table ft join customers cu
	on		ft.customer_id = cu.customer_id

	if @errors > 0
	begin
		print 'WARNING: ' + convert(varchar(200),@errors) + ' rows out of ' 
				+ convert(varchar(200),@totalrows) + ' rows were not updated because their ' +
				'length is not between the shortest and longest length of all the values in ' + 
				'the table for the first_name column'
	end
end
go

--TEST
/*
select top 1 len(first_name) max_len from customers order by max_len asc
select top 1 len(first_name) max_len from customers order by max_len desc

update customers set first_name = 'X' where customer_id = 1
select * from customers where customer_id = 1
*/

/*
5) Using the following table, you are asked to create an automatic audit system for the INSERT, 
UPDATE and DELETE events using AFTER triggers for the planes table. 
In the INSERT event, each column inserted (for each row) must generate a single row in the tb_audit table
In the UPDATE event, each column updated must generate a single row in the tb_audit table
In the DELETE event, each column deleted (for each row) must generate a single row in the tb_audit table
*/

/* TEST CODE FOR TRIGGERS

select * from planes

insert into planes (plane_id)
values (99999)

update planes
set plane_id = , 
	fabrication_date = getdate(), 
	first_use_date = getdate()
where plane_id = 99999

delete from planes where plane_id = 0
delete from planes where plane_id = 99999

select * from tb_audit
select * from planes where plane_id = 99999

*/

if object_id ('tb_audit') is not null
	drop table tb_audit
go

create table tb_audit
(
aud_id				int		identity,		--autogenerated identifier
aud_station			varchar(50),			--name of the computer from which the operation was done
aud_operation		varchar(50),			--type of operation: INSERT, UPDATE or DELETE
aud_date			date,					--date of the operation
aud_time			time,					--time of the operation
aud_username		varchar(50),			--SQL Server login name used for the operation
aud_table			varchar(50),			--table in which the operation was performed
aud_identifier_id	varchar(50),			--value of the id of the tuple affected by the operation
aud_column			varchar(50),			--name of the column affected by the operation
aud_before			varchar(max),			--value of the column before the operation
aud_after			varchar(max)			--value of the column after the operation
)
go

if object_id('tr_planes') is not null
	drop trigger tr_planes
go
create trigger tr_planes
on planes
after insert, update, delete
as
set nocount on
begin
	if exists (select * from inserted) and not exists (select * from deleted)
	begin
		print 'INSERT'
		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'INSERT',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id, 'plane_id', null, plane_id  from inserted

		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after) 	
		select HOST_NAME(),'INSERT',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id, 'fabrication_date',null, fabrication_date  from inserted

		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'INSERT',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id, 'first_use_date',null, first_use_date from inserted
	
		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'INSERT',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id, 'brand',null, brand from inserted

		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'INSERT',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id, 'model',null, model from inserted

		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'INSERT',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id, 'capacity',null, capacity from inserted
	end
	
	else if exists (select * from inserted) and exists (select * from deleted)
	begin
		print 'UPDATE'

		declare @temporalinserted	table	(
		id							int		identity,
		plane_id					int,
		fabrication_date			varchar(800),
		first_use_date				date,
		brand						varchar(800),
		model						varchar(800),
		capacity					int	
		)	
		
		declare @temporaldeleted	table	(
		id							int		identity,
		plane_id					int,
		fabrication_date			varchar(800),
		first_use_date				date,
		brand						varchar(800),
		model						varchar(800),
		capacity					int	
		)

		insert into @temporalinserted (plane_id, fabrication_date, first_use_date, brand, model, capacity)
		select plane_id, fabrication_date, first_use_date, brand, model, capacity from inserted 

		insert into @temporaldeleted (plane_id, fabrication_date, first_use_date, brand, model, capacity)
		select plane_id, fabrication_date, first_use_date, brand, model, capacity from deleted 

		insert into tb_audit (aud_station, aud_operation, aud_date, aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'UPDATE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', ti.plane_id, 'plane_id', td.plane_id, ti.plane_id
		from @temporaldeleted td join @temporalinserted ti
		on td.id = ti.id
		where td.plane_id != ti.plane_id 

		insert into tb_audit (aud_station, aud_operation, aud_date, aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'UPDATE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', ti.plane_id, 'fabrication_date', td.fabrication_date, ti.fabrication_date
		from @temporaldeleted td join @temporalinserted ti
		on td.id = ti.id
		where td.plane_id != ti.plane_id 

		insert into tb_audit (aud_station, aud_operation, aud_date, aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'UPDATE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', ti.plane_id, 'first_use_date', td.first_use_date, ti.first_use_date
		from @temporaldeleted td join @temporalinserted ti
		on td.id = ti.id
		where td.plane_id != ti.plane_id 

		insert into tb_audit (aud_station, aud_operation, aud_date, aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'UPDATE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', ti.plane_id, 'brand', td.brand, ti.brand
		from @temporaldeleted td join @temporalinserted ti
		on td.id = ti.id
		where td.plane_id != ti.plane_id 

		insert into tb_audit (aud_station, aud_operation, aud_date, aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'UPDATE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', ti.plane_id, 'model', td.model, ti.model
		from @temporaldeleted td join @temporalinserted ti
		on td.id = ti.id
		where td.plane_id != ti.plane_id 

		insert into tb_audit (aud_station, aud_operation, aud_date, aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'UPDATE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', ti.plane_id, 'capacity', td.capacity, ti.capacity
		from @temporaldeleted td join @temporalinserted ti
		on td.id = ti.id
		where td.plane_id != ti.plane_id 

	end
	else if not exists (select * from inserted) and exists (select * from deleted)
	begin
		print 'DELETE'
	
		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'DELETE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id,'plane_id', plane_id, null
		from deleted
		
		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'DELETE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id,'fabrication_date', fabrication_date, null
		from deleted

		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'DELETE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id,'first_use_date', first_use_date, null
		from deleted

		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'DELETE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id,'brand', brand, null
		from deleted

		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'DELETE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id,'model', model, null
		from deleted
		
		insert into tb_audit (aud_station,aud_operation,aud_date,aud_time, aud_username, aud_table, aud_identifier_id, aud_column, aud_before, aud_after)
		select HOST_NAME(),'DELETE',GETDATE(),GETDATE(),SYSTEM_USER,'planes', plane_id,'capacity', capacity, null
		from deleted
	end
end


--VIEWS
/*
06) Create a view that shows the following columns

  customer_id column (customers table)
  first_name column (customers table)
  last_name column (customers table)
  birth_date column (customers table)
  current age (from birth_date column) (customers table)
  city name (from name column) (cities_states table)
  
  only return the top 100 first customers ordered by current age in ascendent order and
  birth_date in descendent order
*/

select	top 100
		cu.customer_id, 
		cu.first_name, 
		cu.last_name, 
		birth_date,
		datediff(year,cu.birth_date, getdate()) current_age,
		cs.name
from	customers cu join 
		cities_states cs on cu.city_state_id = cs.city_state_id
order by current_age asc, birth_date desc

/*
07) Create a view on that shows the following columns

  route_id column (routes table)
  name of the city of origin (cities_states table)
  name of the city of destination (cities_states table)
  id of the weekday (weekdays table)
  name of the weekday (weekdays table)
  number of flights made by customers in 2016 and 2017

  only return the top 3 routes for each day of the week in descendent order by number of flights 
  made by customers in 2016 and 2017 
*/

select		position,
			route_id, 
			city_name_origin, 
			city_name_destination, 
			weekday_id,
			weekday_name,
			total_flights			
from
(
								select	ROW_NUMBER() over (partition by weekday_name order by weekday_name, sum(flights) desc) position,
										route_id, 
										city_name_origin, 
										city_name_destination, 
										weekday_id,
										weekday_name,
										sum(flights) total_flights
								from
								(
											select	route_id, 
													city_name_origin, 
													city_name_destination,
													weekday_id,
													weekday_name, 
													sum(flights) flights
											from
											(
													select	ro.route_id,
															cs1.name city_name_origin,
															cs2.name city_name_destination,
															wd.name weekday_name,
															wd.weekday_id weekday_id,
															(select count(*) from tickets where flight_id = fl.flight_id and year(boarding_date) in (2016, 2017)) flights
													from	routes ro join 	cities_states cs1 
													on cs1.city_state_id = ro.city_state_id_origin   join cities_states cs2 on 
													cs2.city_state_id = ro.city_state_id_destination join weekdays wd on 
													wd.weekday_id = ro.weekday_id join flights fl on 
													fl.route_id = ro.route_id
											) a
											group by route_id, city_name_origin, city_name_destination, weekday_id, weekday_name
								) b
								group by route_id, city_name_origin, city_name_destination, weekday_id, weekday_name
) c
where position in (1,2,3)
order by weekday_id, weekday_name, position asc


/*
08) Create a view on that shows the following columns

 name (cities_states table)
 number of flights in 2016 and 2017 by all customers whose address belong to that city
 number of flights in 2016 and 2017 by male customers whose address belong to that city
 number of flights in 2016 and 2017 by female customers whose address belong to that city

 only return rows from the top 20 first cities in descendent order by number of flights in 2016 and 2017 
 by customers whose address belong to that city
*/

select	top 20
		city_name, 
		sum(flights_gender_M) 'flights_gender_M',
		sum(flights_gender_F) 'flights_gender_F',
		sum(flights_total) 'flights_total'
from 
(
		select	cs.name city_name,
				count(*) 'flights_gender_M',
				null 'flights_gender_F',
				null 'flights_total'
		from	cities_states cs join
				customers cu on cu.city_state_id = cs.city_state_id join
				tickets ti on ti.customer_id = cu.customer_id join
				flights fl on fl.flight_id = ti.flight_id
		where year (boarding_date) in (2016, 2017) and gender = 'M'
		group by cs.name
		union 
		select	cs.name city_name,
				null 'flights_gender_M',
				count(*)  'flights_gender_F',
				null 'flights_total'
		from	cities_states cs join
				customers cu on cu.city_state_id = cs.city_state_id join
				tickets ti on ti.customer_id = cu.customer_id join
				flights fl on fl.flight_id = ti.flight_id
		where year (boarding_date) in (2016, 2017) and gender = 'F'
		group by cs.name
		union
		select	cs.name city_name,
				null 'flights_gender_M',
				null 'flights_gender_F',
				count(*) 'flights_total'
		from	cities_states cs join
				customers cu on cu.city_state_id = cs.city_state_id join
				tickets ti on ti.customer_id = cu.customer_id join
				flights fl on fl.flight_id = ti.flight_id
		where year (boarding_date) in (2016, 2017)
		group by cs.name 
) a
group by city_name
order by flights_total desc

/*
9) Create a view that shows the following columns

  name (cities_states table)
  number of customers that flew in 2016 and 2017 whose address belong to that city
  number of flights in 2016 and 2017 by customers whose address belong to that city
  age group, which is a column that classfies customers in 5 groups: 
  
  25 or younger 
  26 to 40
  41 to 55 
  56 to 70  
  71 or older

  only return customers from the top 3 first cities by each age group in descendent 
  order by number of customers that flew in 2016 and 2017 whose address belong to that city 
  and by number of flights in 2016 and 2017 by customers whose address belong to that city
*/

select		position,
			city_name,
			age_group,
			customers_total, 
			flights_total
from
(
			select	ROW_NUMBER() over (partition by age_group order by sum(customers_total) desc) position,
					city_name, 
					age_group,
					sum(customers_total) 'customers_total',
					sum(flights_total) 'flights_total'
			from 
			(
				select	cs.name city_name,
						case	
							when datediff(year, birth_date, getdate()) between 00 and 25 then '00 - 25'
							when datediff(year, birth_date, getdate()) between 26 and 40 then '26 - 40'
							when datediff(year, birth_date, getdate()) between 41 and 55 then '41 - 55'
							when datediff(year, birth_date, getdate()) between 56 and 70 then '56 - 70'
							when datediff(year, birth_date, getdate()) between 71 and 100 then '71 - 100'
						end age_group,
						count(distinct cu.customer_id) 'customers_total',
						count(fl.flight_id) 'flights_total'
				from	cities_states cs join customers cu on cu.city_state_id = cs.city_state_id
				join	tickets ti on ti.customer_id = cu.customer_id 
				join	flights fl on fl.flight_id = ti.flight_id
				where year (boarding_date) in (2016, 2017)
				group by cs.name, birth_date
			) a
group by city_name, age_group
) b
where position in (1,2,3)
group by position, city_name, age_group, customers_total, flights_total
order by age_group, position, flights_total desc 


/*
10) CONSTRAINTS
You are asked to create the indicated number of constraints (you can decide to use either CHECK, 
UNIQUE or DEFAULT) that satisfies the current data on each of the following tables: 

  table_name		columns		constraints
  employees			17			8
  customers			13			6
  tickets			13			6
  locations			7			3
  planes			6			3
  flights			6			3
  routes			6			3
  discounts			6			3
*/