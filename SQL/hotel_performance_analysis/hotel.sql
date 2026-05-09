-- PART A: DDL
SET search_path TO public;

select * from tembo_hotel_dirty;

create schema if not exists tembo_hotel;

set search_path to tembo_hotel;


CREATE TABLE IF NOT EXISTS bookings_staging (
    booking_id          TEXT,  
    guest_name          TEXT,
    guest_phone         TEXT,  
    guest_city          TEXT,
    guest_nationality   TEXT,  
    room_no             TEXT,
    room_type           TEXT,  
    room_rate_per_night TEXT,
    check_in_date       TEXT,  
    check_out_date      TEXT,
    nights_stayed       TEXT,  
    staff_name          TEXT,
    staff_department    TEXT,  
    staff_salary        TEXT,
    payment_method      TEXT,  
    booking_status      TEXT,
    total_amount        TEXT,  
    service_used        TEXT,
    service_price       TEXT,  
    guest_rating        TEXT
);

insert into bookings_staging 
select * from public.tembo_hotel_dirty;

select * from bookings_staging;

select count(*) from bookings_staging;

-- ==========================================
-- ======PART B Audit queries ======================

-- Audit 1 - guest name problems 
select distinct  guest_name from bookings_staging limit 40;
-- we have CAPS need to fix the casing - INITCAP() -> title case	
-- we have names in lowercase - 

-- Audit 2 - room type distinct values
select distinct  room_type, count(*) as count
from bookings_staging group by room_type order by room_type;
/* Expected values: Standard, Deluxe,Suite, Penthouse)
 * dirty values - DLX, Std, standard, deluxe
 * 
 * */

-- Audit 3 - payment method 
select distinct  payment_method from bookings_staging;
-- expected - Mpesa , Card, Bank Transfer , Cash ->title case, standardize Mpesa

-- Audit 4 - booking status
select distinct  booking_status from bookings_staging; -- standardize checked out

-- Audit 5 - phone, city
-- phone 
-- Null or empty string
select guest_name, count(*) from bookings_staging 
where guest_phone is null or trim(guest_phone) = ''
group by guest_name; --one name with 14 nulls

-- phone 
select booking_id, guest_phone from bookings_staging
where guest_phone like '+254%' or guest_phone like '%-%'; -- format to 07...

-- city
select distinct guest_city from bookings_staging; -- Thikax -> Thika, initcap, empties


select * from bookings_staging;

-- salary, total amount: remove the KES, only numbers
select distinct staff_salary from bookings_staging;

select distinct total_amount from bookings_staging;

select distinct service_used from bookings_staging; -- empties

select distinct service_price from bookings_staging; -- nulls

select distinct guest_rating from bookings_staging;

select distinct 
	case
		when trim(guest_city) ='Thikax' then 'Thika'
		else initcap(trim(guest_city))
	end as guestcity_
from bookings_staging;


-- Audit 6 - Ratings 
select booking_id, guest_name , guest_rating from bookings_staging
where 
	trim(guest_rating) not in ('1', '2', '3', '4', '5') or 
	trim(guest_rating) = ''; -- we have 0s and 6s

-- Audit 7 - Date Format problems
select booking_id, check_in_date, check_out_date 
from bookings_staging 
where check_in_date not similar to '[0-9]{4}-[0-9]{2}-[0-9]{2}'; --inconsistent; format to "yyyy-mm-dd"


-- Part C: Data Cleaning
-- 1. Standardization(casing and trimming)
begin;

update bookings_staging
set 
	guest_name = initcap(trim(guest_name)),
	guest_city = initcap(trim(guest_city)),
	payment_method = initcap(trim(payment_method)),
	booking_status = initcap(trim(booking_status));

select guest_name, guest_city from bookings_staging limit 20;	

select * from bookings_staging;

commit;


-- 2. Mapping(room_type)
-- Standard, Deluxe, Suite, Penthouse
select distinct room_type,
	case 
		when room_type in ('Deluxe', 'DLX','deluxe') then 'Deluxe'
		when room_type in ('Std', 'standard', 'Standard') then 'Standard'
		else initcap(trim(room_type))
	end as room_type_fixed,
	guest_city,
	case
		when trim(guest_city) = 'Thikax' then 'Thika'
		else guest_city
	end as guest_city_fixed
from bookings_staging;

begin;

update bookings_staging
set 
	room_type = case
		when room_type in ('Deluxe', 'DLX','deluxe') then 'Deluxe'
		when room_type in ('Std', 'standard', 'Standard') then 'Standard'
		else initcap(trim(room_type))	
	end,
	guest_city = case
		when trim(guest_city) = 'Thikax' then 'Thika'
		else guest_city
	end;

-- quick check
select distinct room_type, guest_city from bookings_staging;

commit;

-- 3. Formatting: Dates and phone numbers

-- A. Date Formatting
begin; 

update bookings_staging
set
	check_in_date = case
		when check_in_date like '%/%' then to_date(check_in_date, 'DD/MM/YYYY')
		when check_in_date similar to '[0-9]{2}-[0-9]{2}-[0-9]{2}' then to_date(check_in_date, 'DD-MM-YY')
		else check_in_date::date 
	end,
	check_out_date = case
		when check_out_date like '%/%' then to_date(check_out_date, 'DD/MM/YYYY')
		when check_out_date similar to '[0-9]{2}-[0-9]{2}-[0-9]{2}' then to_date(check_out_date, 'DD-MM-YY')
		else check_out_date::date
	end;

-- verify
select check_in_date, check_out_date from bookings_staging ;

commit;

-- B. Phone formatting
update bookings_staging
set 
	-- remove everything except numbers then replace '254' prefix with '0'
	guest_phone = regexp_replace(regexp_replace(nullif(trim(guest_phone), ''), '\D', '', 'g'), 
                    '^254', '0');

select guest_phone from bookings_staging;

commit;

-- C. Total amount and salary formatting
begin;

update bookings_staging
set 
	staff_salary = nullif(regexp_replace(staff_salary, '[^0-9.]', '', 'g'), '')::numeric,
	total_amount = nullif(regexp_replace(total_amount, '[^0-9.]', '', 'g'), '')::numeric,
	service_price = nullif(regexp_replace(service_price, '[^0-9.]', '', 'g'), '')::numeric;

--preview
select staff_salary, total_amount, service_price
from bookings_staging;

commit;

-- 3. Fix rating range( 1 to 5)
begin;

update bookings_staging
set 
	guest_rating = case
		when trim(guest_rating) in ('1', '2', '3', '4', '5') then guest_rating
		else null
	end;

select guest_rating from bookings_staging
where guest_rating not in ('1', '2', '3', '4', '5') and guest_rating is not null;

commit;

--4. Global nulling for empties
select * from bookings_staging;
-- Step 1: Empties count
select 
    COUNT(*) FILTER (WHERE TRIM(guest_name) = '') AS name_empties,
    COUNT(*) FILTER (WHERE TRIM(guest_phone) = '') AS phone_empties,
    COUNT(*) FILTER (WHERE TRIM(service_used) = '') AS service_empties,
    COUNT(*) FILTER (WHERE TRIM(staff_salary) = '') AS salary_empties,
    COUNT(*) FILTER (WHERE TRIM(total_amount) = '') AS amount_empties,
    COUNT(*) FILTER (WHERE TRIM(guest_rating) = '') AS rating_empties,
    count(*) filter (where trim(guest_city) = '' ) as city_empties
FROM bookings_staging;

begin;

update bookings_staging
set
	-- guest details
	guest_name = nullif(TRIM(guest_name), ''),
    guest_phone = nullif(TRIM(guest_phone), ''),
    guest_city = nullif(TRIM(guest_city), ''),
    guest_nationality = nullif(TRIM(guest_nationality), ''),
    
    -- Booking details
    room_no = nullif(TRIM(room_no), ''),
    room_type = nullif(TRIM(room_type), ''),
    booking_status = nullif(TRIM(booking_status), ''),
    
    -- Financials
    room_rate_per_night = nullif(TRIM(room_rate_per_night), ''),
    staff_salary = nullif(TRIM(staff_salary), ''),
    total_amount = nullif(TRIM(total_amount), ''),
    service_price = nullif(TRIM(service_price), ''),
    
    -- Services and Ratings
    service_used = nullif(TRIM(service_used), ''),
    guest_rating = nullif(TRIM(guest_rating), ''),
    
    -- Staff info
    staff_name = nullif(TRIM(staff_name), ''),
    staff_department = nullif(TRIM(staff_department), '');

 --sample check
  select count(*) from bookings_staging where service_used='';
 
 select * from bookings_staging;
 
 commit;
 
 -- 5. Other fixes
 -- A. payment method (M-pesa -> Mpesa)
 select distinct payment_method from bookings_staging;
 
 begin;
 
 update bookings_staging
 set
 	payment_method = case
 		when payment_method in ('M-pesa', 'Mpesa', 'M-Pesa') then 'Mpesa'
 		else payment_method
 	end;
 
 commit;
 
-- 6. Duplicate handling
 -- check for dupes
select booking_id, count(*) from bookings_staging
group by booking_id having count(*) > 1;

select booking_id, guest_name, check_in_date, room_no,count(*)
from bookings_staging
group by booking_id ,guest_name, check_in_date, room_no
having count(*) > 1;

-- deleting them
begin;

delete from bookings_staging
where ctid not in (
	select min(ctid)
	from bookings_staging
	group by booking_id
	);

-- check row count
select count(*) from bookings_staging;

commit;

-- random checks for the nulls
-- total amount
select booking_id, room_rate_per_night , nights_stayed , total_amount , booking_status
from bookings_staging
where total_amount is null;

select booking_id, room_rate_per_night , nights_stayed , total_amount , booking_status, service_used, service_price
from bookings_staging
where total_amount is not null
limit 10;

-- staff salary nulls
select   staff_name , staff_salary
from bookings_staging
where staff_salary is null; --only 2(Tony Karanja and Peter Ngugi)

select distinct staff_name , staff_salary
from bookings_staging
where staff_name ='Tony Karanja' or staff_name = 'Peter Ngugi';  

select distinct staff_department from bookings;

--guest phonenumber
select * from bookings_staging
where guest_phone is null;

select * from bookings_staging
where guest_phone is null or guest_name = 'Patrick Ngugi';

-- services and charges 
select * from bookings_staging
where service_used is null or service_price is null;


-- ========== PART D ==========================
-- Create production table and load clean data .
drop table if exists bookings; -- next time try truncate table bookings to clear the data alone

create table if not exists bookings(
		booking_id VARCHAR(10) primary key,
		guest_name VARCHAR(100) not null,
	    guest_phone VARCHAR(20),
	    guest_city VARCHAR(50),
	    guest_nationality VARCHAR(50),
	    check_in_date DATE not null,
	    check_out_date DATE not null,
	    nights_stayed INT,
	    room_no INT,
	    room_type VARCHAR(20),
	    room_rate_per_night NUMERIC(10, 2),
	    total_amount NUMERIC(10, 2),
	    payment_method VARCHAR(30),
	    booking_status VARCHAR(20),
	    service_used VARCHAR(100),
	    service_price NUMERIC(10, 2),
	    guest_rating INT check (guest_rating between 1 and 5),
	    staff_name VARCHAR(100),
	    staff_department VARCHAR(50),
	    staff_salary NUMERIC(10, 2)
);
begin;

-- load data(nulls handled here)
insert into bookings
select 
	booking_id,
    guest_name,
    coalesce(guest_phone, 'Not provided') as guest_phone,
    coalesce(guest_city, 'Unknown') as guest_city,
    guest_nationality,
    check_in_date::DATE,
    check_out_date::DATE,
    nights_stayed::INT,
    room_no::INT,
    room_type,
    replace(room_rate_per_night, ',' ,'')::numeric as room_rate_per_night,
    -- calculate missing total amount
    case
    	when total_amount is null
    	then (replace(room_rate_per_night, ',' ,'')::numeric * nights_stayed::INT)
    		+ coalesce(replace(service_price, ',', '')::numeric, 0)
    	else replace(total_amount, ',','')::numeric
    end as total_amount,
    payment_method,
    booking_status,
    -- Clean the service categorical and numerical columns
    coalesce(service_used, 'None') as service_used,
    -- replace nulll service prices with 0
    coalesce(replace(service_price, ',', '')::NUMERIC,0) as service_price,
    guest_rating::INT,
    staff_name,
    staff_department,
    -- Impute missing known salaries
    case
    	when staff_name = 'Tony Karanja' then 32000
    	when staff_name = 'Peter Ngugi' then 30000
    	else replace(staff_salary, ',','')::numeric
    end as staff_salary  
from bookings_staging;

rollback;

commit;

select distinct room_no from bookings_staging;

select * from bookings;

-- Part E: Analysis

-- total revenue
select sum(total_amount) as total_revenue from bookings;

select round(avg(guest_rating), 1) as avg_rating from bookings;

-- REVENUE
-- 1. Revenue By Month
select to_char(check_in_date, 'Month') as month, sum(total_amount)
from bookings
group by month, extract('month'from check_in_date)
order by extract('month'from check_in_date) asc;

-- 2. Revenue By room type
-- Show total revenue, number of bookings, average revenue per booking,
-- and average guest rating - all grouped by room type. Order by total revenue descending.
select room_type,count(booking_id) as total_bookings, round(avg(guest_rating), 2) as avg_guest_rating, --nulls not included in averages
	round(avg(total_amount),2) as average_revenue, sum(total_amount) as total_revenue
from bookings
group by room_type 
order by total_revenue desc;

-- 3. Revenue By Payment method
select payment_method, count(*), sum(total_amount) as total_revenue
from bookings
group by payment_method 
order by sum(total_amount) desc;

-- 4. Revenue Pivot
select to_char(check_in_date, 'Month') as month,
    sum(case when payment_method = 'Mpesa' then total_amount else 0 end) as mpesa,
    sum(case when payment_method = 'Cash' then total_amount else 0 end) as cash,
    sum(case when payment_method = 'Card' then total_amount else 0 end) as card,
    sum(case when payment_method = 'Bank Transfer' then total_amount else 0 end) as bank_transfer
from bookings
group by extract(month from check_in_date), to_char(check_in_date, 'Month')
order by extract(month from check_in_date);

-- sidenote(you can use (COALESCE(SUM(total_amount) FILTER (WHERE payment_method = 'Mpesa'), 0) AS mpesa,) instead of case )

-- OCCUPANCY
-- 1. Bookings and Occupancy by room_type
select * from bookings;

select room_type ,count(*) as total_bookings, sum(nights_stayed) as total_nights_stayed ,
	round(avg(nights_stayed), 0) as avg_night_per_booking, round(sum(total_amount)/sum(nights_stayed),2) as revenue_per_night,
	sum(total_amount) as total_revenue
from bookings
group by room_type
order by sum(total_amount ) desc;

-- 2. Occupancy By Month
select to_char(check_in_date, 'Month') as month, count(*) as total_bookings,
	sum(nights_stayed) as total_nights_occupied
from bookings
group by extract(month from check_in_date), to_char(check_in_date, 'Month')
order by extract(month from check_in_date) asc;

-- December has highest all

-- 3.Average stay length by guest city
--Do guests from different cities stay longer? Show: guest_city, average nights stayed, average total amount, number of bookings. Only include cities with at least 3 bookings.
select guest_city, count(*) as total_bookings, round(avg(nights_stayed),0) as avg_nights_stayed, 
	round(AVG(total_amount), 2) as avg_amount
from bookings
group by guest_city
having count(*) >= 3;

-- GUEST STATS
-- 1. Top 10 guest cities
-- guest_city, number of guests, total revenue from that city, and average rating.
select guest_city, count(*) as number_of_guests, sum(total_amount) as total_revenue,
	round(avg(guest_rating), 1) as avg_rating
from bookings
group by guest_city 
order by count(*) desc
limit 10;

-- 2. Guest satisfaction by room type -g
select room_type, round(AVG(guest_rating), 2) as avg_rating,
	round(count(guest_rating) filter (where guest_rating in(4,5))* 100.0 /count(guest_rating), 2) as happy_percent
from bookings
group by room_type ; -- percentage should sum upto 100%

-- 3. Repeat guests
select guest_name, guest_city, count(booking_id) as total_bookings, sum(total_amount) as total_spent,
	round(avg(guest_rating),1) as avg_rating
from bookings
group by guest_name, guest_city
having count(booking_id) >1
order by count(booking_id) desc;

-- 4. Sentiment breakdown (CTE)

with sentiment_counts as(
	-- Bucket ratings into categories and count them
    select 
        case 
            when guest_rating in (4, 5) then 'Happy'
            when guest_rating = 3 then 'Neutral'
            when guest_rating in (1, 2) then 'Unhappy'
            else 'No Rating' 
        end as sentiment,
        count(*) as category_count
    from bookings
    group by 
        case 
            when guest_rating in(4, 5) then 'Happy'
            when guest_rating = 3 then 'Neutral'
            when guest_rating in (1, 2) then 'Unhappy'
            else 'No Rating' 
        end
)
-- Calculate the percentages from those counts
select 
    sentiment,
    category_count as total_bookings,
    trunc((category_count * 100.0) / sum(category_count) over(), 2) as percentage
from sentiment_counts
order by total_bookings desc;


-- STAFF PERFOMANCE
--  1. Staff booking performance
select staff_name, sum(total_amount) as total_revenue, round(avg(guest_rating), 1) as avg_guest_rating
from bookings
group by staff_name, staff_department 
order by sum(total_amount) desc;

-- 2. Department Summary
select staff_department, count(*) as total_bookings, sum(total_amount) as total_revenue,
	round(avg(staff_salary),2) as avg_salary, count(distinct staff_name) as staff_count
from bookings
group by staff_department
order by sum(total_amount) desc;

select count(distinct(staff_name)) from bookings;

-- 3. staff ranking with window function
with staff_totals as (
    select staff_name, staff_department,
        count(*) as total_bookings,
        sum(total_amount) as total_revenue
    from bookings
    group by staff_name, staff_department
)
select staff_name, staff_department, total_bookings, total_revenue,
    rank() over (order by total_revenue desc) as overall_rank,
    rank() over (partition by staff_department order by total_revenue desc) as dept_rank
from staff_totals
order by total_revenue desc;


-- REVENUE TRENDS
-- 1. month-over-month revenue change
with monthly_revenue as (
	-- Get base revenue for each month
    select to_char(check_in_date, 'YYYY-MM') as month,
        sum(total_amount) as revenue
    from bookings
    group by to_char(check_in_date, 'YYYY-MM')
)
select month, revenue,
	-- get previous month rev and the change
    lag(revenue) over (order by month) as prev_month_revenue,
    revenue - lag(revenue) over (order by month) as change_amount,
    round((revenue - lag(revenue) over (order by month)) / lag(revenue) over (order by month) * 100.0, 1) as change_pct
from monthly_revenue
order by month;


-- 2. running total of revenue
with monthly_revenue as (
    select to_char(check_in_date, 'YYYY-MM') as month,
        sum(total_amount) as revenue
    from bookings
    group by to_char(check_in_date, 'YYYY-MM')
)
select month, revenue,
    sum(revenue) over (order by month) as cumulative_revenue
from monthly_revenue
order by month;


-- 3. best and worst performing months
with monthly_revenue as (
    select to_char(check_in_date, 'Month') as month,
        sum(total_amount) as revenue
    from bookings
    group by to_char(check_in_date, 'Month')
),
-- chain second CTE to get ranks
ranked_months as (
    select month, revenue,
        rank() over (order by revenue desc) as top_rank,
        rank() over (order by revenue asc) as bottom_rank
    from monthly_revenue
)
select month, revenue, 'top 3' as performance_tier
from ranked_months
where top_rank <= 3
union all
select month, revenue, 'bottom 3' as performance_tier
from ranked_months
where bottom_rank <= 3
order by revenue desc;


-- CANCELLATIONS & LOST REVENUE
-- 1. overall booking status breakdown -g
select booking_status,
    count(*) as status_count,
    round((count(*) * 100.0) / sum(count(*)) over (), 2) as status_percentage
from bookings
group by booking_status;


-- 2. cancellation rate by room type
select room_type,
    count(*) as total_bookings,
    count(*) filter (where booking_status = 'Checked Out') as checked_out_count,
    count(*) filter (where booking_status = 'Cancelled') as cancelled_count,
    count(*) filter (where booking_status = 'No Show') as no_show_count,
    round((count(*) filter (where booking_status = 'Cancelled') * 100.0) / count(*), 2) as cancellation_rate_pct
from bookings
group by room_type;



-- 3. lost revenue from cancellations and no-shows -g
select booking_status,
    count(*) as status_count,
    sum(total_amount) as total_revenue
from bookings
group by booking_status
order by total_revenue desc;



select distinct to_char(check_in_date, 'YYYY-MM') as year from bookings;

-- waah we have 2023 and 2024

-- 4. Cancellation by month
with monthly_cancellations as (
    --  Filter and group the data 
    select 
        to_char(check_in_date, 'YYYY-MM')as month,
        count(*) AS cancellation_count
    from bookings
    where booking_status = 'Cancelled'
    group by to_char(check_in_date, 'YYYY-MM')
)
--  Query the CTE to find the highest month
select 
    month, 
    cancellation_count
from monthly_cancellations
order by cancellation_count desc;

-- PART F: CREATING VIEWS
-- view 1: monthly revenue summary
create or replace view v_monthly_revenue as
select 
    to_char(check_in_date, 'YYYY-MM') as month,
    sum(total_amount) as revenue
from bookings
group by to_char(check_in_date, 'YYYY-MM');

-- view 2: room type performance (combined revenue and occupancy)
create or replace view v_room_performance as
select 
    room_type,
    count(booking_id) as total_bookings,
    sum(nights_stayed) as total_nights_stayed,
    round(avg(nights_stayed), 0) as avg_night_per_booking,
    round(avg(guest_rating), 2) as avg_guest_rating,
    sum(total_amount) as total_revenue,
    round(sum(total_amount)/sum(nights_stayed), 2) as revenue_per_night
from bookings
group by room_type;

-- view 3: staff performance
create or replace view v_staff_performance as
select 
    staff_name, 
    staff_department,
    sum(total_amount) as total_revenue, 
    round(avg(guest_rating), 1) as avg_guest_rating
from bookings
group by staff_name, staff_department;

-- view 4: guest city summary
create or replace view v_guest_insights as
select 
    guest_city, 
    count(*) as total_bookings, 
    round(avg(nights_stayed), 0) as avg_nights_stayed, 
    round(avg(total_amount), 2) as avg_amount
from bookings
group by guest_city
having count(*) >= 3;

-- bonus view: cancellation analysis
create or replace view v_cancellation_analysis as
select 
    room_type,
    count(*) as total_bookings,
    count(*) filter (where booking_status = 'Checked Out') as checked_out_count,
    count(*) filter (where booking_status = 'Cancelled') as cancelled_count,
    count(*) filter (where booking_status = 'No Show') as no_show_count,
    round((count(*) filter (where booking_status = 'Cancelled') * 100.0) / count(*), 2) as cancellation_rate_pct
from bookings
group by room_type;

-- PART G: Creating Indexes















