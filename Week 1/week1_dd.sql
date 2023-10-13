
IF OBJECT_ID('sales', 'U') IS NOT NULL
    DROP TABLE sales;

IF OBJECT_ID('members', 'U') IS NOT NULL
    DROP TABLE members;

IF OBJECT_ID('menu', 'U') IS NOT NULL
    DROP TABLE menu;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);
INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),   
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');


-- 1. What is the total amount each customer spent at the restaurant?
SELECT
    s.customer_id,
    sum(m.price) as total_amount_spent
FROM
    menu m
inner JOIN
    sales s
on m.product_id = s.product_id
GROUP BY
    s.customer_id
order by 
    total_amount_spent desc;

-- 2. How many days has each customer visited the restaurant?
SELECT
    s.customer_id,
    count(Distinct s.order_date) as total_days_visited
FROM
    menu m
inner JOIN
    sales s
on m.product_id = s.product_id
GROUP BY
    s.customer_id
order by 
    total_days_visited desc;


--3. What was the first item from the menu purchased by each customer?
with cte_first_item_tmp AS
(
SELECT
    s.customer_id,
    m.product_name,
    DENSE_RANK() over(PARTITION by s.customer_id order by s.order_date) as row_num
FROM
    menu m   
inner JOIN
    sales s
on m.product_id = s.product_id
)
SELECT 
    Distinct 
    customer_id, 
    product_name
FROM    
    cte_first_item_tmp
where 
    row_num = 1;

--4 What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT Top 1
    m.product_name,
    count(*) as most_purchased_count
FROM
    sales s
inner JOIN
    menu m
on s.product_id = m.product_id
group BY
    m.product_name
order by 
    most_purchased_count DESC;

--5 Which item was the most popular for each customer?

with cte_item_ranked as
(
SELECT
    customer_id,
    product_id,
    COUNT(*) AS order_count,
    Rank() over (partition by customer_id order by count(*) DESC) as popularity_rank
FROM
    sales
  GROUP BY
    customer_id,
    product_id
)
SELECT
    cte_item_ranked.customer_id,
    menu.product_name,
    cte_item_ranked.order_count
FROM
    cte_item_ranked
INNER JOIN
    menu
on cte_item_ranked.product_id = menu.product_id
WHERE
    cte_item_ranked.popularity_rank = 1;

--Which item was purchased first by the customer after they became a member?

with cte_date_diff AS
(
    SELECT
        members.customer_id,
        product_id,
        sales.order_date
    FROM
        sales
    inner JOIN
        members
    on sales.order_date > members.join_date
    and members.customer_id = sales.customer_id)
,
cte_ranked as
(
SELECT 
    customer_id,
    product_name,
    Rank() over (partition by customer_id order by order_date) as first_order
from cte_date_diff
inner JOIN
    menu
on cte_date_diff.product_id = menu.product_id
)
select 
    customer_id,
    product_name
from 
    cte_ranked
where 
    first_order =  1 ;

--Alternative

With cte_first_order_ranked as
(
SELECT
    sales.customer_id,
    product_id,
    sales.order_date,
    Rank() OVER (PARTITION by sales.customer_id order by order_date ) as first_order_rank
from
    sales
inner JOIN
    members
on members.customer_id = sales.customer_id
and sales.order_date > members.join_date
)
SELECT 
    customer_id,
    product_name
from
    cte_first_order_ranked
inner join
    menu
on cte_first_order_ranked.product_id = menu.product_id
WHERE
    first_order_rank = 1;


--Which item was purchased just before the customer became a member?

With cte_rank_before_member as
(
SELECT
    sales.customer_id,
    product_id,
    sales.order_date,
    Rank() OVER (PARTITION by sales.customer_id order by order_date DESC ) as rank_before_member
from
    sales
inner JOIN
    members
on members.customer_id = sales.customer_id
and sales.order_date < members.join_date
)
SELECT 
    cte_rank_before_member.customer_id,
    product_name
from
    cte_rank_before_member
inner join
    menu
on cte_rank_before_member.product_id = menu.product_id
WHERE
    rank_before_member = 1;


---What is the total items and amount spent for each member before they became a member?

SELECT
    sales.customer_id,
    count(sales.product_id ) as total_items,
    sum(menu.price) as amount_spent
from
    sales
inner JOIN
    members
on members.customer_id = sales.customer_id
and sales.order_date < members.join_date
inner JOIN
    menu 
on sales.product_id = menu.product_id
GROUP BY
    sales.customer_id;

---If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH cte_indvidual_price_list
AS
(
SELECT
    customer_id,
    case when menu.product_name = 'sushi' then menu.price*20 else 0 end as sushi_price,
    case when menu.product_name != 'sushi' then menu.price*10 else 0 end as other_price
FROM
    sales
inner join menu
on sales.product_id = menu.product_id
)
select
    customer_id,
    sum(sushi_price)+ sum(other_price) as total_points
from 
    cte_indvidual_price_list
group BY
    customer_id;


--In the first week after a customer joins the program (including their join date) they earn 2x points on all items not just sushi - how many points do customer A and B have at the end of January?

with CTE_date_checker as 
(SELECT
    s.customer_id,
    m.product_id,
    m.product_name,
    m.price,
    s.order_date,
    DATEDIFF(DAY, members.join_date, s.order_date) AS days_after_join
FROM
    sales s
inner join members 
on s.customer_id = members.customer_id
inner join menu m
on s.product_id = m.product_id
WHERE
     s.order_date >= members.join_date
    AND s.order_date <= DATEADD(DAY, 31, members.join_date) -- End of January
)
SELECT
    customer_id,
    SUM(
        CASE
            WHEN days_after_join <= 7 THEN price * 20
            ELSE price
        END
    ) AS total_points
        
from
    CTE_date_checker
GROUP BY
   customer_id ;




--- BONUS QUESTION ---

--Join All The Things
SELECT
    sales.customer_id,
    sales.order_date,
    menu.product_name,
    menu.price,
    CASE
        when sales.order_date >= members.join_date  THEN 'Y' else 'N' end as member

FROM
    sales
inner join 
    menu
on sales.product_id = menu.product_id
left join members
on sales.customer_id = members.customer_id;



--Rank All The Things

with cte_member_data as 
(
SELECT
    sales.customer_id,
    sales.order_date,
    menu.product_name,
    menu.price,
    CASE
        when sales.order_date >= members.join_date  THEN 'Y' else 'N' end as member

FROM
    sales
inner join 
    menu
on sales.product_id = menu.product_id
left join members
on sales.customer_id = members.customer_id
),
cte1 as 
(
select
    *,
    DENSE_RANK() over(PARTITION by customer_id order by order_date) as rank
FROM
    cte_member_data
where member = 'Y'
),
cte2 as 
(
select
    *,
    null as rank
FROM
    cte_member_data
where member = 'N'
)

select * from cte1
UNION All
select * from cte2
order by customer_id, member;

