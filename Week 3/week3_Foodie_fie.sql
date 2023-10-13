
--Customer Journey

/*Customer 1: This customer initially joined the trial plan but upgraded to the basic monthly plan a week later.
Customer 2: Customer 2 also started with a trial plan and quickly switched to the pro annual plan seven days later.
Customer 11: This customer began with a trial plan and then decided to cancel their service, resulting in a churn record after seven days.
Customer 13: Customer 13's journey began with a trial, followed by an upgrade to the basic monthly plan a week later, and then an upgrade to the pro monthly plan several months afterward.
Customer 15: Initially on a trial, customer 15 upgraded to the pro monthly plan a week later and later had a churn record after about a month.
Customer 16: Starting with a trial, customer 16 upgraded to the basic monthly plan a week later and then upgraded to the pro annual plan several months afterward.
Customer 18: Customer 18 joined the trial and then upgraded to the pro monthly plan a week later.
Customer 19: This customer, too, started with a trial, upgraded to the pro monthly plan a week later, and later switched to the pro annual plan a couple of months after that.
*/

--Analysis 
--1. How many customers has Foodie-Fi ever had?

SELECT count(Distinct customer_id) FROM foodie_fi.subscriptions;

--2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value

SELECT
    Extract(MONTH from start_date) as starting_month,
    TO_CHAR(start_date, 'Month') AS month_name,
    count(*) as total_customers
FROM 
    foodie_fi.subscriptions s
inner join
    foodie_fi.plans p
on 
    s.plan_id = p.plan_id
where 
    s.plan_id = 0
group by
    starting_month,month_name
order by
    total_customers DESC

--3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT
    pl.plan_name as plan_name,
    count(*) as number_of_events
FROM
    foodie_fi.subscriptions sub
INNER JOIN
    foodie_fi.plans pl
    on sub.plan_id = pl.plan_id
WHERE 
    Extract(YEAR FROM start_date) = 2021
GROUP BY
    plan_name


--4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?


Select 
    sum(Case when sub.plan_id = 4 then 1 else 0 end) as number_of_churned_customers,
    Round((sum(Case when sub.plan_id = 4 then 1 else 0 end)*100.0/
    count(Distinct customer_id)),1)
    as percentage_of_churned_customers
FROM
    foodie_fi.subscriptions sub
INNER JOIN
    foodie_fi.plans pl
on sub.plan_id = pl.plan_id 

Alternative

SELECT
    COUNT(DISTINCT customer_id) AS customer_count,
    ROUND(
        (SUM(CASE WHEN plan_id = 1 THEN 1 ELSE 0 END) * 100.0) / COUNT(DISTINCT customer_id),
        1
    ) AS churned_percentage
FROM
    foodie_fi.subscriptions;

--5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

with cte1 as
(
SELECT
    customer_id,
    plan_id,
    LEAD(plan_id) over(Partition by customer_id order by start_date)
    as next_plan_id
FROM
    foodie_fi.subscriptions
)
select 
    count(customer_id),
    Round(count(customer_id)*100.0/(select count(distinct customer_id) from foodie_fi.subscriptions))
From
    cte1
where
    plan_id = 0 and next_plan_id=4


   
---7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
with cte_ranked as
(
SELECT
    customer_id,
    s.plan_id,
    plan_name,
    start_date,
    Rank() Over(Partition by customer_id order by start_date DESC) as       ranked
FROM 
    foodie_fi.subscriptions s
inner join
    foodie_fi.plans p
on 
    s.plan_id = p.plan_id
WHERE 
    start_date <= '2020-12-31'
)

select
    plan_id,
    plan_name,
    count(*) as customer_count,
    Round(count(*)*100.0/(select count(distinct customer_id) from foodie_fi.subscriptions),1) as customer_percentage
from
    cte_ranked
where
    ranked=1
group by
    plan_id,plan_name
order by
    plan_id
    
-- 8. How many customers have upgraded to an annual plan in 2020?
select
    count(Distinct customer_id) as customers_upgraded_to_annual_subs
FROM
    foodie_fi.subscriptions s
inner join
    foodie_fi.plans p
on s.plan_id = p.plan_id
where 
    s.plan_id = 3
    and
    Extract(year from start_date) = 2020


--8 How many days on average does it take for a customer to join an annual plan from the day they join Foodie-Fi?

with cte_max_plan as 
(
Select
    customer_id,
    plan_id,
    start_date,
    Max(plan_id) over (partition by customer_id) as max_plan
From
    foodie_fi.subscriptions
)
,
cte_max_min_dates as
(
select 
    customer_id,
    max(start_date)-min(start_date) as daydiff  
from 
    cte_max_plan
where
    max_plan=3
group by
    customer_id
)

select
    Floor(avg(daydiff)) as average_days
from 
    cte_max_min_dates
    
-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH CustomerAnnualSwitch AS (
    SELECT
        s.customer_id,
        MIN(s.start_date) AS join_date,
        MAX(CASE WHEN p.plan_id = 3 THEN s.start_date END) AS annual_plan_date
    FROM
        foodie_fi.subscriptions s
    INNER JOIN
        foodie_fi.plans p
    ON
        s.plan_id = p.plan_id
    WHERE
        p.plan_id IN (0,3) 
    GROUP BY
        s.customer_id
),

DateDifference AS (
    SELECT
        CASE
            WHEN (annual_plan_date - join_date) BETWEEN 0 AND 30 THEN '0-30 days'
            WHEN (annual_plan_date - join_date) BETWEEN 31 AND 60 THEN '31-60 days'
            WHEN (annual_plan_date - join_date) BETWEEN 61 AND 90 THEN '61-90 days'
            ELSE 'More than 90 days'
        END AS period,
        (annual_plan_date - join_date) AS difference
    FROM
        CustomerAnnualSwitch
)
SELECT
    period,
    ROUND(AVG(difference)) AS average_days
FROM
    DateDifference
GROUP BY
    period
ORDER BY
    period;
    
--How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

with next_plan_cte as 
(
SELECT
    s.customer_id,
    p.plan_name,
    s.start_date,
    Lead(p.plan_name) over(Partition by s.customer_id order by s.start_date ) as next_plan
From 
    foodie_fi.subscriptions s
inner join 
    foodie_fi.plans p
on 
    p.plan_id = s.plan_id
where
     DATE_PART('year', start_date) = 2020
)
select
    count(*) as pro_to_basic_monthly
from
    next_plan_cte
where
    plan_name = 'pro monthly'
    and
    next_plan = 'basic monthly'





    

    

    