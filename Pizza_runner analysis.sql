USE pizza_runner;  -- Select the 'pizza_runner' database

SET SQL_SAFE_UPDATES = 0;  -- Temporarily disable safe update mode to allow modifications

-- Retrieve data from various tables for inspection and analysis
SELECT * FROM customer_orders;
SELECT * FROM pizza_names;
SELECT * FROM pizza_recipes;
SELECT * FROM pizza_toppings;
SELECT * FROM runner_orders;
SELECT * FROM runners;

-- Clean up null and empty values in the 'customer_orders' table
UPDATE customer_orders
SET exclusions = NULL
WHERE exclusions IN ('', 'null');

UPDATE customer_orders
SET extras = NULL
WHERE extras IN ('null', '');

-- Clean up null and empty values in the 'runner_orders' table
UPDATE runner_orders
SET distance = NULL
WHERE distance = 'null';

UPDATE runner_orders
SET duration = NULL
WHERE duration = 'null';

UPDATE runner_orders
SET cancellation = NULL
WHERE cancellation = '' OR cancellation = 'null';

UPDATE runner_orders
SET pickup_time = NULL
WHERE pickup_time = 'null';

-- Normalize the 'distance' and 'duration' columns in the 'runner_orders' table
UPDATE runner_orders
SET distance = CASE 
    WHEN distance = 'null' THEN NULL
    WHEN distance LIKE '%km' THEN TRIM(REPLACE(distance, 'km', ''))
    ELSE distance
END;

UPDATE runner_orders
SET duration = CASE 
    WHEN duration LIKE '%min%' THEN SUBSTRING(duration, 1, 2)
    ELSE duration
END;

-- Rename columns for clarity
ALTER TABLE runner_orders
RENAME COLUMN distance TO distance_km;

ALTER TABLE runner_orders
RENAME COLUMN duration TO duration_min;

-- Convert columns to appropriate data types for data integrity
ALTER TABLE runner_orders
MODIFY COLUMN pickup_time TIMESTAMP;

ALTER TABLE runner_orders
MODIFY COLUMN distance_km FLOAT;

ALTER TABLE runner_orders
MODIFY COLUMN duration_min INTEGER;

-- Create a clean pizza recipes table for easier analysis
CREATE TABLE clean_pizza_recipes (
    pizza_id INT,
    toppings VARCHAR(255)
);

INSERT INTO clean_pizza_recipes
SELECT pizza_id, SUBSTRING_INDEX(SUBSTRING_INDEX(toppings, ',', n), ',', -1) AS topping
FROM pizza_runner.pizza_recipes
CROSS JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) AS numbers
WHERE n <= LENGTH(toppings) - LENGTH(REPLACE(toppings, ',', '')) + 1;

-- Pizza Metrics Queries

-- How many pizzas were ordered?
SELECT COUNT(order_id) AS Number_Of_Pizza_Ordered
FROM customer_orders;

-- How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS Unique_orders
FROM customer_orders;

-- How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(*) AS orders_delivered
FROM runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id;

-- How many of each type of pizza was delivered?
SELECT pizza_name, COUNT(*) AS total_pizza_delivered
FROM customer_orders c
JOIN pizza_names p USING(pizza_id)
JOIN runner_orders r ON c.order_id = r.order_id
WHERE cancellation IS NULL
GROUP BY pizza_name;

-- How many Vegetarian and Meatlovers were ordered by each customer?
SELECT c.customer_id, p.pizza_name, COUNT(*) AS Count_of_order
FROM pizza_names p
RIGHT JOIN customer_orders c USING(pizza_id)
GROUP BY customer_id, p.pizza_name;

-- What was the maximum number of pizzas delivered in a single order?
WITH maximum_pizza AS (
    SELECT c.order_id, COUNT(*) AS total_pizza_delivered
    FROM customer_orders c
    INNER JOIN pizza_names p USING(pizza_id)
    INNER JOIN runner_orders r ON c.order_id = r.order_id
    WHERE r.cancellation IS NULL
    GROUP BY c.order_id
)

SELECT order_id, total_pizza_delivered
FROM maximum_pizza
GROUP BY order_id
ORDER BY total_pizza_delivered DESC
LIMIT 1;

-- For each customer, how many delivered pizzas had at least 1 change, and how many had no changes?
SELECT c.order_id, c.customer_id, 
    SUM(CASE WHEN (exclusions IS NOT NULL OR exclusions != 0) OR
        (extras IS NOT NULL OR extras != 0) THEN 1 ELSE 0 END) AS At_least_One_Change,
    SUM(CASE WHEN (exclusions IS NULL OR exclusions = 0) OR
        (extras IS NULL OR extras = 0) THEN 1 ELSE 0 END) AS No_change
FROM customer_orders c
INNER JOIN runner_orders r
WHERE r.cancellation IS NULL
GROUP BY c.order_id, c.customer_id;

-- How many pizzas were delivered that had both exclusions and extras?
SELECT c.order_id, c.customer_id,
    SUM(CASE WHEN (exclusions IS NOT NULL) AND (extras IS NOT NULL) THEN 1 ELSE 0 END) AS pizza_exclusions_extras
FROM customer_orders c
INNER JOIN runner_orders r USING(order_id)
WHERE r.cancellation IS NULL
GROUP BY c.order_id, c.customer_id
ORDER BY pizza_exclusions_extras DESC;

-- What was the total volume of pizzas ordered for each hour of the day?
SELECT EXTRACT(hour from order_time) AS hourlydata, COUNT(order_id) AS Total_pizza_ordered
FROM customer_orders
GROUP BY hourlydata
ORDER BY hourlydata;

-- What was the volume of orders for each day of the week?
SELECT DAYNAME(order_time) AS DailyData, COUNT(order_id) AS TotalPizzaOrdered
FROM customer_orders
GROUP BY DailyData
ORDER BY TotalPizzaOrdered DESC;