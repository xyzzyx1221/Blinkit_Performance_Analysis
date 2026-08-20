
SHOW TABLES;
SELECT COUNT(*) FROM blinkit_customers;

-- SECTION A: DASHBOARD-MATCHING VISUAL QUERIES (5)

-- Q1. Revenue by Customer Segmentation
-- OBJECTIVE: Find out which customer segment (Premium, Regular,
--            New, Inactive) brings in the most revenue.
-- FINDING:   Regular customers generate the highest revenue
--            (₹28.90 lakh from 1,320 orders), slightly ahead of
--            New (₹27.96 lakh) and Premium (₹27.31 lakh).
--            This is notable because Regular customers are
--            outperforming the "Premium" tier in total revenue,
--            even though Premium customers are expected to spend
--            more per order.
SELECT
    c.customer_segment,
    ROUND(SUM(o.order_total), 2) AS total_revenue,
    COUNT(DISTINCT o.order_id)   AS total_orders
FROM blinkit_customers c
JOIN blinkit_orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_segment
ORDER BY total_revenue DESC;

-- Q2. Payment Method Segmentation
-- OBJECTIVE: See which payment methods customers use most, to
--            guide which payment options to promote or optimize.
-- FINDING:   Card (26.03%) and Cash (25.16%) are used slightly
--            more than Wallet (24.66%) and UPI (24.15%). The
--            spread is fairly even across all four methods — no
--            single payment method dominates, so the business
--            should keep supporting all four rather than
--            favoring one.
SELECT
    payment_method,
    ROUND(SUM(order_total), 2) AS revenue,
    ROUND(100.0 * SUM(order_total) / (SELECT SUM(order_total) FROM blinkit_orders), 2) AS pct_of_revenue
FROM blinkit_orders
GROUP BY payment_method
ORDER BY revenue DESC;

-- Q3. Area Wise Performance (Top 10)
-- OBJECTIVE: Identify the top-performing delivery areas by
--            revenue, to help decide where to focus marketing
--            or open new dark stores.
-- FINDING:   Orai (₹99.6K) and Deoghar (₹95.4K) are the top two
--            revenue-generating areas, followed by Nandyal,
--            Gandhinagar, and Bhopal. These areas are strong
--            candidates for continued investment or expansion.
SELECT
    c.area,
    ROUND(SUM(o.order_total), 2) AS revenue,
    COUNT(DISTINCT o.order_id)   AS total_orders
FROM blinkit_customers c
JOIN blinkit_orders o ON c.customer_id = o.customer_id
GROUP BY c.area
ORDER BY revenue DESC
LIMIT 10;

-- Q4. Delivery Status Distribution
-- OBJECTIVE: Understand what share of all deliveries are on time
--            versus delayed, to gauge overall delivery health.
-- FINDING:   69.40% of deliveries are On Time, 20.74% are
--            Slightly Delayed, and 9.86% are Significantly
--            Delayed. Roughly 3 in 10 deliveries face some
--            delay, which is a meaningful chunk worth
--            investigating further.
SELECT
    delivery_status,
    COUNT(*) AS total_deliveries,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM blinkit_delivery_performance), 2) AS pct
FROM blinkit_delivery_performance
GROUP BY delivery_status
ORDER BY total_deliveries DESC;

-- Q5. Customer Sentiment vs Delivery Status
-- OBJECTIVE: Check whether delayed deliveries actually lead to
--            more negative customer feedback.
-- FINDING:   The split between Positive (~32-33%), Neutral
--            (~33-36%), and Negative (~32-34%) sentiment stays
--            roughly the same whether delivery was On Time or
--            Significantly Delayed. This confirms delivery delay
--            alone is NOT the main driver of negative feedback —
--            other factors (product quality, app experience,
--            etc.) likely matter just as much or more.
SELECT
    dp.delivery_status,
    cf.sentiment,
    COUNT(*) AS feedback_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY dp.delivery_status), 2) AS pct_within_status
FROM blinkit_customer_feedback cf
JOIN blinkit_delivery_performance dp ON cf.order_id = dp.order_id
GROUP BY dp.delivery_status, cf.sentiment
ORDER BY dp.delivery_status, cf.sentiment;


-- SECTION B: DEEPER CROSS-DOMAIN DATA ANALYSIS (15)

-- Q6. Top 10 Customers by Total Order Value
-- OBJECTIVE: Identify the highest-value customers who should be
--            prioritized for loyalty programs or personal outreach.
-- FINDING:   The top customer (Rayaan Krishna) has spent ₹21,686.80
--            across 6 orders. This list matches the dashboard's
--            "Top Customers Leaderboard" exactly, confirming the
--            underlying data and the dashboard numbers are
--            consistent with each other.
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    ROUND(SUM(o.order_total), 2) AS total_order_value,
    COUNT(o.order_id)            AS total_orders
FROM blinkit_customers c
JOIN blinkit_orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name, c.customer_segment
ORDER BY total_order_value DESC
LIMIT 10;

-- Q7. Monthly Revenue & Order Volume Trend
-- OBJECTIVE: Track how revenue and order volume have changed
--            over time, to spot growth or decline patterns.
-- FINDING:   Revenue started around ₹2.73 lakh in March 2023 and
--            climbed steadily through mid-2023 (₹5.5L in April,
--            ₹6.1L in May) as order volume grew. This matches
--            the shape of the dashboard's "Customer Growth
--            Trend" chart, which also shows growth through 2023
--            before leveling off in 2024.
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    COUNT(*)                          AS total_orders,
    ROUND(SUM(order_total), 2)        AS revenue,
    ROUND(AVG(order_total), 2)        AS avg_order_value
FROM blinkit_orders
GROUP BY month
ORDER BY month;

-- Q8. City-Wise Average Rating (Reliable Sample Only)
-- OBJECTIVE: Find which cities have the happiest customers,
--            while filtering out cities with too few reviews to
--            trust (a city with only 1 review could show a
--            misleading 5-star average).
-- FINDING:   Filtering to cities with at least 10 reviews gives
--            a more trustworthy ranking than the raw dashboard
--            numbers. Confirmed: Mangalore's dashboard "5.00"
--            rating is based on exactly 1 review — not a real
--            signal. With the reliability filter applied,
--            Davanagere (4.08, n=12) leads instead.
SELECT
    c.area,
    ROUND(AVG(cf.rating), 2) AS avg_rating,
    COUNT(*)                  AS feedback_count
FROM blinkit_customer_feedback cf
JOIN blinkit_customers c ON cf.customer_id = c.customer_id
GROUP BY c.area
HAVING feedback_count >= 10
ORDER BY avg_rating DESC
LIMIT 10;

-- Q9. Cities with Highest / Lowest Average Delivery Delay  [CORRECTED]
-- OBJECTIVE: Pinpoint which cities have the worst and best
--            delivery timing performance, to help target
--            operational fixes.
-- FINDING: delivery_time_minutes = actual_time minus
--            promised_time (verified against raw timestamps, 0
--            mismatches across 5,000 rows) — positive = late,
--            negative = early. Restricting to cities with at
--            least 10 deliveries for a reliable sample:
--            Medininagar (+9.29 min, n=17) and Thoothukudi
--            (+9.25 min, n=20) show the highest average delay.
--            No city with a reliable sample shows a strongly
--            negative (much-earlier) average — the best
--            performers (Delhi -0.07, Gulbarga +0.19) are close
--            to zero, not dramatically ahead of schedule. The
--            company-wide average delay is +4.44 minutes, so
--            this looks more like a modest, general lateness
--            tendency than a small set of outlier "problem
--            cities."
SELECT
    c.area,
    ROUND(AVG(dp.delivery_time_minutes), 2) AS avg_delay_minutes,
    COUNT(*) AS delivery_count
FROM blinkit_delivery_performance dp
JOIN blinkit_orders o ON dp.order_id = o.order_id
JOIN blinkit_customers c ON o.customer_id = c.customer_id
GROUP BY c.area
HAVING delivery_count >= 10
ORDER BY avg_delay_minutes DESC
LIMIT 5;

SELECT
    c.area,
    ROUND(AVG(dp.delivery_time_minutes), 2) AS avg_delay_minutes,
    COUNT(*) AS delivery_count
FROM blinkit_delivery_performance dp
JOIN blinkit_orders o ON dp.order_id = o.order_id
JOIN blinkit_customers c ON o.customer_id = c.customer_id
GROUP BY c.area
HAVING delivery_count >= 10
ORDER BY avg_delay_minutes ASC
LIMIT 5;

-- Q10. Product Category Wise Damaged Stock
-- OBJECTIVE: Find which product categories suffer the most
--            damage during storage or handling, to guide
--            packaging or handling improvements.
-- FINDING:   Household Care shows the highest damage ratio
--            (0.682) among all product categories, followed by
--            Personal Care (0.615). Baby Care has the lowest
--            (0.498). All ratios stay under 1.0, so there is no
--            evidence of a data-quality error where damaged
--            stock exceeds received stock — but the consistently
--            high ratios across categories (43-68%) may itself
--            be worth flagging, since even the best-performing
--            category is losing over 40% of received stock to
--            damage.
SELECT
    p.category,
    SUM(i.stock_received)                                    AS total_received,
    SUM(i.damaged_stock)                                      AS total_damaged,
    ROUND(1.0 * SUM(i.damaged_stock) / SUM(i.stock_received), 3) AS damage_ratio
FROM blinkit_inventory i
JOIN blinkit_products p ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY damage_ratio DESC;

-- Q11. Monthly Inventory Damage Trend  [CORRECTED]
-- OBJECTIVE: Track how much stock gets damaged each month, to
--            spot seasonal patterns or sudden spikes.
-- FINDING:   Grouping by month-of-year (across both years in the
--            dataset) reproduces the dashboard exactly: damage
--            rises from ~4.2K in January to a peak around 8.3K
--            in May, July, August, and October, and drops
--            sharply to 4.8K in November and 4.1K in December.
--            This does look like a genuine seasonal pattern
--            (higher damage in the warmer/monsoon months)
--            rather than noise.
SELECT
    MONTHNAME(date) AS month_name,
    MONTH(date)      AS month_num,
    SUM(damaged_stock) AS total_damaged_stock
FROM blinkit_inventory
GROUP BY MONTHNAME(date), MONTH(date)
ORDER BY month_num;

-- Q12. Delivery Time vs Rating Correlation  [CORRECTED]
-- OBJECTIVE: Check whether longer delivery times actually lead
--            to lower customer ratings.
-- FINDING: Ratings do NOT decline monotonically.
--            On Time = 3.33, Slightly Delayed = 3.39 (actually
--            higher), Significantly Delayed = 3.33 (back to the
--            same level as On Time). There is no meaningful
--            relationship between delivery time and rating in
--            this data — ratings stay essentially flat
--            (3.33-3.39) regardless of delay severity. This
--            reinforces Q5's finding even more strongly than
--            originally stated: delivery delay is not a
--            meaningful driver of customer satisfaction here.
SELECT
    dp.delivery_status,
    ROUND(AVG(dp.delivery_time_minutes), 2) AS avg_delivery_time,
    ROUND(AVG(cf.rating), 2)                 AS avg_rating
FROM blinkit_delivery_performance dp
JOIN blinkit_customer_feedback cf ON dp.order_id = cf.order_id
GROUP BY dp.delivery_status
ORDER BY avg_delivery_time;

-- Q13. Feedback Category Wise Sentiment Breakdown  [CORRECTED]
-- OBJECTIVE: See if any one feedback category (Delivery, App
--            Experience, Customer Service, Product Quality)
--            is driving most of the negative sentiment.
-- CORRECTED FINDING: Negative sentiment ranges from 31.86%
--            (Delivery) to 34.56% (Product Quality) — a ~2.7
--            percentage-point spread, wider than "31-32%"
--            implies, but still fairly even. Product Quality has
--            the highest negative share and the lowest positive
--            share (30.24%) of the four categories, making it a
--            marginally weaker area than the rest — worth a
--            closer look — but no category is dramatically worse
--            than the others.
SELECT
    feedback_category,
    sentiment,
    COUNT(*) AS feedback_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY feedback_category), 2) AS pct_within_category
FROM blinkit_customer_feedback
GROUP BY feedback_category, sentiment
ORDER BY feedback_category, sentiment;

-- Q14. Top-Selling Product per Category by Revenue (Window Function)
-- OBJECTIVE: Find the single best-selling product within each
--            category, to know which products to always keep
--            in stock.
-- FINDING:   Bread leads Dairy & Breakfast (₹1.85 lakh), Onions
--            leads Fruits & Vegetables (₹1.39 lakh), Baby Wipes
--            leads Baby Care (₹1.59 lakh), Toilet Cleaner leads
--            Household Care (₹2.00 lakh), and Vitamins leads
--            Pharmacy (₹2.61 lakh) — the single highest-revenue
--            product of any category. These are the products the
--            business can least afford to run out of stock on.
SELECT category, product_name, revenue, rnk
FROM (
    SELECT
        p.category,
        p.product_name,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
        RANK() OVER (PARTITION BY p.category ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS rnk
    FROM blinkit_order_items oi
    JOIN blinkit_products p ON oi.product_id = p.product_id
    GROUP BY p.category, p.product_name
) ranked
WHERE rnk = 1;

-- Q15. Repeat Customers vs One-Time Customers
-- OBJECTIVE: Measure how many customers come back to order again,
--            a key sign of business health and customer loyalty.
-- FINDING:   1,492 customers (68.7%) are repeat customers, while
--            680 (31.3%) have only ordered once. A majority-
--            repeat customer base is a healthy sign, but the
--            31% one-time customers represent an opportunity for
--            a "win-back" campaign.
SELECT
    CASE WHEN order_count = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
    COUNT(*) AS num_customers
FROM (
    SELECT customer_id, COUNT(*) AS order_count
    FROM blinkit_orders
    GROUP BY customer_id
) t
GROUP BY customer_type;

-- Q16. Average Rating by Customer Segment
-- OBJECTIVE: Check whether the segment that pays the most
--            (Premium) is also the segment that is happiest.
-- FINDING:   Premium customers give the LOWEST average rating
--            (3.32) of all four segments, while Inactive
--            customers give the highest (3.37). This is a
--            counter-intuitive and important finding — the
--            customers spending the most are, on average, the
--            least satisfied.
SELECT
    c.customer_segment,
    ROUND(AVG(cf.rating), 2) AS avg_rating,
    COUNT(*)                  AS feedback_count
FROM blinkit_customer_feedback cf
JOIN blinkit_customers c ON cf.customer_id = c.customer_id
GROUP BY c.customer_segment
ORDER BY avg_rating DESC;

-- Q17. At-Risk Customers: Negative Feedback + Delayed Delivery, by Segment  [CORRECTED]
-- OBJECTIVE: Find customers who had BOTH a delayed delivery AND
--            gave negative feedback — the customers most likely
--            to churn — and see which segment they belong to.
-- CORRECTED FINDING: At-risk customers are nearly evenly
--            distributed across all segments: Regular (118),
--            New (117), Premium (116), Inactive (110). The
--            spread is narrow (~7% between highest and lowest),
--            indicating this is a company-wide delivery/service
--            issue rather than one concentrated in a specific
--            customer segment. Service recovery efforts should
--            likely be prioritized by delivery/operational cause
--            rather than by customer segment.
SELECT
    c.customer_segment,
    COUNT(DISTINCT c.customer_id) AS at_risk_customers
FROM blinkit_customer_feedback cf
JOIN blinkit_delivery_performance dp ON cf.order_id = dp.order_id
JOIN blinkit_customers c ON cf.customer_id = c.customer_id
WHERE cf.sentiment = 'Negative'
  AND dp.delivery_status <> 'On Time'
GROUP BY c.customer_segment
ORDER BY at_risk_customers DESC;

-- Q18. Second-Highest Order Value
-- OBJECTIVE: Find the second-highest single order value placed,
--            without relying only on LIMIT (a common interview
--            question to test handling of duplicate top values).
-- FINDING:   The highest order value is ₹6,721.46; the
--            second-highest is ₹6,543.19.
SELECT DISTINCT order_total
FROM blinkit_orders
ORDER BY order_total DESC
LIMIT 1 OFFSET 1;

-- Q19. Category Revenue Contribution (Order Items + Products)
-- OBJECTIVE: See which product categories generate the most
--            actual revenue, not just the most orders.
-- FINDING:   Dairy & Breakfast is the top revenue-generating
--            category (₹6.39 lakh from 1,114 units sold),
--            followed by Pharmacy (₹5.92 lakh) and Fruits &
--            Vegetables (₹5.59 lakh). These three categories
--            should be the business's top priority for stock
--            availability and promotions.
SELECT
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
    SUM(oi.quantity)                            AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price) / SUM(oi.quantity), 2) AS avg_price_per_unit
FROM blinkit_order_items oi
JOIN blinkit_products p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;

-- Q20. Customers with Above-Average Order Value but Below-Average Rating  [CORRECTED]
-- OBJECTIVE: Find high-spending customers who are quietly
--            unhappy — customers who bring in strong revenue but
--            rate their experience poorly. These are high-value,
--            high-risk customers worth reaching out to directly.
-- FINDING:   With the fan-out bug fixed, the original finding's
--            numbers turn out to be exactly correct: Neelima Raj
--            (Premium) averages ₹5,768.29 per order but rates
--            only 3.00, and Lajita Ghosh (New) averages
--            ₹5,453.47 per order but rates just 1.00. Several
--            other high-spenders (₹4,800-5,700 avg order value)
--            also show below-average ratings. These customers
--            should be flagged for priority retention outreach,
--            since losing them would cost more than losing an
--            average customer.
WITH cust_orders AS (
    SELECT customer_id, AVG(order_total) AS avg_order_value
    FROM blinkit_orders
    GROUP BY customer_id
),
cust_feedback AS (
    SELECT customer_id, AVG(rating) AS avg_rating
    FROM blinkit_customer_feedback
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    ROUND(co.avg_order_value, 2) AS avg_order_value,
    ROUND(cf.avg_rating, 2)      AS avg_rating
FROM blinkit_customers c
JOIN cust_orders co ON c.customer_id = co.customer_id
JOIN cust_feedback cf ON c.customer_id = cf.customer_id
WHERE co.avg_order_value > (SELECT AVG(order_total) FROM blinkit_orders)
  AND cf.avg_rating < (SELECT AVG(rating) FROM blinkit_customer_feedback)
ORDER BY co.avg_order_value DESC
LIMIT 10;
