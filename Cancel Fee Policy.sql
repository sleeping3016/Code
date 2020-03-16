-- schema

exec sp_help lyft_data

-- sample data

select top 5 * from dbo.ride_data
select top 100 * from dbo.experiment_data

-- count rows

select count (*) from dbo.ride_data
select count (*) from dbo.experiment_data

-- create table to join ride to exp

select		a.*
			, b.variant
			, b.cancel_penalty

into		dbo.lyft_data

from		dbo.ride_data as a

join		experiment_data as b

on			a.rider_id = b.rider_id

-- overall cnt
select		variant
			,	cancel_penalty
			,	count (ride_id)

from		dbo.lyft_data

group by	variant
			,	cancel_penalty

-- division 

select local

from 
(
SELECT SUBSTRING( accepted_at_local, 33, 100) as local

from dbo.lyft_data
) as a

group by local

-- cancel only


select * from dbo.lyft_data where cancellation_flag = 1

-- data process

drop table if exists dbo.lyft_data2

select		b.*
			,	case 
				when eta_to_rider_pre_match_rank <= 350578 then '0-25th percentile'
				when eta_to_rider_pre_match_rank <= 701156 then '26-50th percentile'
				when eta_to_rider_pre_match_rank <= 1051734 then '51-75th percentile'
				when eta_to_rider_pre_match_rank <= 1402312 then '76-100th percentile'
				end as eta_to_rider_pre_match_group
			,	case 
				when eta_to_rider_post_match_rank <= 350578 then '0-25th percentile'
				when eta_to_rider_post_match_rank <= 701156 then '26-50th percentile'
				when eta_to_rider_post_match_rank <= 1051734 then '51-75th percentile'
				when eta_to_rider_post_match_rank <= 1402312 then '76-100th percentile'
				end as eta_to_rider_post_match_group
			,	case 
				when upfront_fare_rank <= 350578 then '0-25th percentile'
				when upfront_fare_rank <= 701156 then '26-50th percentile'
				when upfront_fare_rank <= 1051734 then '51-75th percentile'
				when upfront_fare_rank <= 1402312 then '76-100th percentile'
				end as upfront_fare_group
			,	case 
				when discount_rank <= 350578 then '0-25th percentile'
				when discount_rank <= 701156 then '26-50th percentile'
				when discount_rank <= 1051734 then '51-75th percentile'
				when discount_rank <= 1402312 then '76-100th percentile'
				end as discount_group

into		dbo.lyft_data2

from		
(
select		a.*
			,	case
				when cancellation_flag = 1 and accepted_at_local is null then 'pre_accept_cancel'
				else 'post_accept_cancel'
				end as cancel_point
			,	row_number()over(order by eta_to_rider_pre_match asc) as eta_to_rider_pre_match_rank
			,	row_number()over(order by eta_to_rider_post_match asc) as eta_to_rider_post_match_rank
			,	row_number()over(order by upfront_fare asc) as upfront_fare_rank
			,	(upfront_fare - rider_paid_amount) as discount
			,	((upfront_fare - rider_paid_amount) / upfront_fare) as dicount_percent
			,	row_number()over(order by ((upfront_fare - rider_paid_amount) / upfront_fare) asc) as discount_rank
			,	SUBSTRING(requested_at_local, 12,2) as time_of_day
			,	datename(weekday,convert(datetime,SUBSTRING(requested_at_local, 1,10), 102)) as day_of_week 
			,	datepart(weekday,convert(datetime,SUBSTRING(requested_at_local, 1,10), 102)) as day_of_week_num
			,	SUBSTRING(requested_at_local, 1,10) as request_date

from		dbo.lyft_data as a
) as b


---- expriment overall output

select		request_date
			,	variant
			,	count (distinct ride_id) as request_cnt
			,	sum (cast(cancellation_flag as int)) as cancel
			,	sum (rider_paid_amount) as rider_paid_amount
			,	sum (rider_paid_amount*rider_paid_amount) as rider_paid_amount_sq

from		dbo.lyft_data2 

group by	request_date
			,	variant

order by	request_date
			,	variant

--check
select sum (cast(cancellation_flag as int)) from  dbo.ride_data
select sum (rider_paid_amount) from  dbo.ride_data
select top 100* from dbo.lyft_data2 

---- create rider agg table


drop table if exists dbo.lyft_rider1


select		rider_id
			,	variant
			,	cancel_penalty
			,	max(isnull(cast(rider_request_number as int),0)) as total_request
			,	sum(isnull(cast(cancellation_flag as int),0)) as total_cancel
			,	(max(isnull(cast(rider_request_number as int),0)) - sum(isnull(cast(cancellation_flag as int),0))) as effective_request
			,	square(max(isnull(cast(rider_request_number as int),0)) - sum(isnull(cast(cancellation_flag as int),0))) as effective_request_square
			,	sum(isnull(upfront_fare,0)) as total_upfront
			,	sum(isnull(rider_paid_amount,0)) as total_paid
			,	square(sum(isnull(rider_paid_amount,0))) as total_paid_square

into		dbo.lyft_rider1

from		dbo.lyft_data2 as a

group by	rider_id
			,	variant
			,	cancel_penalty

---- experiment output

select		variant
			,	count(distinct rider_id) as rider_cnt
			,	sum (total_request) as total_request
			,	sum (total_cancel) as total_cancel
			,	sum (effective_request) as effective_request
			,	sum (effective_request_square) as effective_request_square
			,	sum (total_paid) as total_paid
			,	sum (total_paid_square) as total_paid_square


from		dbo.lyft_rider1

group by	variant

order by	variant





---- create rider agg table


drop table if exists dbo.lyft_rider2


select		rider_id
			,	variant
			,	request_date
			,	cancel_penalty
			,	count(distinct ride_id) as total_request
			,	sum(isnull(cast(cancellation_flag as int),0)) as total_cancel
			,	(count(distinct ride_id) - sum(isnull(cast(cancellation_flag as int),0))) as effective_request
			,	square(max(isnull(cast(rider_request_number as int),0)) - sum(isnull(cast(cancellation_flag as int),0))) as effective_request_square
			,	sum(isnull(upfront_fare,0)) as total_upfront
			,	sum(isnull(rider_paid_amount,0)) as total_paid
			,	square(sum(isnull(rider_paid_amount,0))) as total_paid_square

into		dbo.lyft_rider2

from		dbo.lyft_data2 as a

group by	rider_id
			,	variant
			,	request_date
			,	cancel_penalty


---- output

select		variant
			,	request_date
			,	sum(effective_request) as effective_request
			,	sum(total_paid) as total_paid

from		dbo.lyft_rider2

group by	variant
			,	request_date

order by	variant
			,	request_date


---- time of day & day of week

select		variant
			,	day_of_week_num
			,	time_of_day
			,	count(distinct ride_id) as total_request
			,	sum(isnull(cast(cancellation_flag as int),0)) as total_cancel
			,	sum(isnull(upfront_fare,0)) as total_upfront
			,	sum(isnull(rider_paid_amount,0)) as total_paid

from		dbo.lyft_data2

group by	variant
			,	day_of_week_num
			,	time_of_day

order by	variant
			,	day_of_week_num
			,	time_of_day

---- cancel window (cancel prior or post accept)

select		variant
			,	cancel_point
			,	count(distinct ride_id) as total_request
			,	sum(isnull(cast(cancellation_flag as int),0)) as total_cancel
			,	sum(isnull(upfront_fare,0)) as total_upfront
			,	sum(isnull(rider_paid_amount,0)) as total_paid

from		dbo.lyft_data2

where		cancellation_flag = 1

group by	variant
			,	cancel_point

order by	variant
			,	cancel_point

---- share type

select		variant
			,	ride_type
			,	count(distinct ride_id) as total_request
			,	sum(isnull(cast(cancellation_flag as int),0)) as total_cancel
			,	sum(isnull(upfront_fare,0)) as total_upfront
			,	sum(isnull(rider_paid_amount,0)) as total_paid

from		dbo.lyft_data2

group by	variant
			,	ride_type

order by	variant
			,	ride_type

---- upfront fare

select		variant
			,	upfront_fare_group
			,	count(distinct ride_id) as total_request
			,	sum(isnull(cast(cancellation_flag as int),0)) as total_cancel
			,	sum(isnull(upfront_fare,0)) as total_upfront
			,	sum(isnull(rider_paid_amount,0)) as total_paid

from		dbo.lyft_data2

group by	variant
			,	upfront_fare_group

order by	variant
			,	upfront_fare_group

---- ETA diff

select		variant
			,	round((eta_to_rider_post_match - eta_to_rider_pre_match)/60,0) as eta_diff
			,	count(distinct ride_id) as total_request
			,	sum(isnull(cast(cancellation_flag as int),0)) as total_cancel
			,	sum(isnull(upfront_fare,0)) as total_upfront
			,	sum(isnull(rider_paid_amount,0)) as total_paid

from		dbo.lyft_data2

group by	variant
			,	round((eta_to_rider_post_match - eta_to_rider_pre_match)/60,0)

order by	variant
			,	round((eta_to_rider_post_match - eta_to_rider_pre_match)/60,0)

---- request to acceptance

select		datediff(mi,SUBSTRING(requested_at_local, 1,19),SUBSTRING(accepted_at_local, 1,19)) as time_to_accept
			,	count(distinct ride_id) as total_request
			,	sum(isnull(cast(cancellation_flag as int),0)) as total_cancel
			,	sum(isnull(upfront_fare,0)) as total_upfront
			,	sum(isnull(rider_paid_amount,0)) as total_paid


from		lyft_data2

group by	datediff(mi,SUBSTRING(requested_at_local, 1,19),SUBSTRING(accepted_at_local, 1,19))
order by	datediff(mi,SUBSTRING(requested_at_local, 1,19),SUBSTRING(accepted_at_local, 1,19))




---- 
