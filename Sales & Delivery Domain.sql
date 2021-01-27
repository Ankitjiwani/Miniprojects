use sql2_mini_project;


# 1 - Join all the tables and create a new table called combined_table 
# (cust_dimen, market_fact, orders_dimen, prod_dimen, shipping_dimen)
# Solution 1 :


CREATE TABLE combined_table AS
SELECT
market.Ord_id, market.Prod_id, market.Ship_id, market.Cust_id, Sales,
Discount, Order_Quantity, Profit, Shipping_Cost, Product_Base_Margin,
cust.Customer_Name, cust.Province, cust.Region, cust.Customer_Segment,
orders.Order_Date, orders.Order_Priority, prod.Product_Category,
prod.Product_Sub_Category, orders.Order_ID, ship.Ship_Mode,
ship.Ship_Date
FROM
market_fact AS market
INNER JOIN
cust_dimen AS cust ON market.Cust_id = cust.Cust_id
INNER JOIN
orders_dimen AS orders ON orders.Ord_id = market.Ord_id
INNER JOIN
prod_dimen AS prod ON prod.Prod_id = market.Prod_id
INNER JOIN
shipping_dimen AS ship ON ship.Ship_id = market.Ship_id;

select * from combined_table;

-- ------------------------------- USING THIS TABLE (combined_table) TO SOLVE FOLLOWING QUESTIONS -------------------------------------------------
      
# 2 - Find the top 3 customers who have the maximum number orders
# Solution 2 :


select Cust_id, Customer_Name, count(ord_id) as 'Number of orders'
from combined_table
group by Cust_id
order by count(ord_id) desc
limit 3;


# 3 - Create a new column 'DayTakenForDelivery' that contains the date difference of order_date and ship_date

# For this question, first converting the order_date and ship_date into datatype date (the default datatype while importing is text)

# Step 1 : Converting the data first into the default sql date format (yyyy-mm-dd)
update combined_table
set Order_Date = str_to_date(Order_date, '%d-%m-%Y');

update combined_table
set Ship_Date = str_to_date(Ship_Date, '%d-%m-%Y');

# Step 2 : Altering the datatype of the columns (order_date and ship_date)
alter table combined_table
modify order_date date;

alter table combined_table
modify Ship_Date date;

# Solution 3 :

alter table combined_table
add column DayTakenForDelivery int;

update combined_table
set DayTakenForDelivery = datediff(Ship_Date, Order_date);


# 4 - Find the customer whose order took the maximum time to get delivered
# Solution 4 :


select *
from combined_table
order by DayTakenForDelivery desc
limit 1;


# 5 - Retrieve total sales made by each product from the data (use Windows function)
# Solution 5 :


select distinct Prod_id, 
sum(sales) over(partition by prod_id) as Total_Sales
from combined_table;


# 6 - Retrieve total profit made from each product from the data (use Windows function)
# Solution 6 :
 
 
select distinct Prod_id, 
sum(profit) over(partition by prod_id) as Total_Profit
from combined_table;
# Note : Here, the negative values denote that the product incurred loss. 
# Since, it is asked for all products hence, these products are also included.


# 7 - Count the total number of unique customers in January and how many of them came back every month over the entrie year in 2011
# Solution 7 :


select distinct monthname(order_date) as Month, count(cust_id) over
(partition by month(order_date) order by month(order_date))
Total_Unique_Customers
from combined_table
where year(order_date) = 2011 and cust_id
in (select distinct cust_id
from combined_table
where month(order_date) = 01
and year(order_date) = 2011);


# 8 - Retrive month by month customer retention rate since the start of the businesses (using views)
# Solution 8 :


# Step 1 : Creating a view for calculating the visit month of each customer with reference to start of business date

Create view Visit_log AS
SELECT cust_id, TIMESTAMPDIFF(month,'2009-01-01', order_date) AS visit_month
FROM combined_table
GROUP BY 1,2
ORDER BY 1,2;

# Step 2 : Creating a view in order to calculate the time lapse

Create view Time_Lapse AS
SELECT distinct cust_id, visit_month,
lead(visit_month, 1) over(
partition BY cust_id
ORDER BY cust_id, visit_month) lap FROM Visit_log;

# Using above view to create a view that gives the visit month along with the month in which customer visited again next time

CREATE VIEW user_retention AS
SELECT DISTINCT customer_name, YEAR(order_date) AS `Year`, MONTH(order_date) AS visit_month,
LEAD(MONTH(order_date),1) 
OVER(PARTITION BY customer_name,year(order_date) ORDER BY MONTH(ORDER_DATE)) AS next_visit_month
FROM combined_table
order by YEAR(order_date);

# Step 3 : Creating a view to calculate time lapse i.e the difference between visits

Create view time_lapse_calculated as
SELECT cust_id,
visit_month,
lap, lap - visit_month AS time_diff
from Time_Lapse;

# Step 4 : Based on the time lapse calculated in the above view, we categorise the customers into 3 categories as required

Create view customer_category as
SELECT cust_id,
visit_month,
CASE
WHEN time_diff = 1 THEN 'retained'
WHEN time_diff > 1 THEN 'irregular'
WHEN time_diff IS NULL THEN 'churned'
END as cust_category
FROM time_lapse_calculated;

# Step 5 : Lastly, we calculate the retention rate based on customers who fall in the 'retained' category in the customer category view

SELECT visit_month as 'Month of Visit', (COUNT(if
(cust_category = 'retained', 1, NULL)) / COUNT(cust_id)) AS 'Retention Rate'
FROM customer_category 
GROUP BY 1 
order by visit_month;

# This query finally gives the month wise retention rate of customers.
