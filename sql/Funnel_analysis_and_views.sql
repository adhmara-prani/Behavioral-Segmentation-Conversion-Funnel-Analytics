USE ecommerce_funnel;

CREATE OR REPLACE VIEW master_session_summary AS
WITH funnel_flags AS (
    SELECT 
        u.session_id,
        u.traffic_source,
        u.browser,
        MAX(CASE WHEN e.event_type = 'home' THEN 1 ELSE 0 END) AS hit_home,
        MAX(CASE WHEN e.event_type = 'department' THEN 1 ELSE 0 END) AS hit_dept,
        MAX(CASE WHEN e.event_type = 'product' THEN 1 ELSE 0 END) AS hit_product,
        MAX(CASE WHEN e.event_type = 'cart' THEN 1 ELSE 0 END) AS hit_cart,
        MAX(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased,
        -- Calculate session duration
        TIMESTAMPDIFF(SECOND, MIN(e.created_at), MAX(e.created_at)) AS session_duration_sec,
        COUNT(e.event_id) AS total_events
    FROM users u
    LEFT JOIN events e ON u.session_id = e.session_id
    GROUP BY u.session_id, u.traffic_source, u.browser
)
SELECT 
    *,
    -- New Behavioral Segmentation
    CASE 
        WHEN purchased = 1 THEN '1. Buyer'
        WHEN hit_cart = 1 THEN '2. Cart Abandoner'
        WHEN hit_product = 1 AND session_duration_sec > 60 THEN '3. Engaged Window Shopper'
        ELSE '4. Bouncer / Low Intent'
    END AS customer_segment,
    
    -- Revenue Simulation (Assigns a random value between 50 and 300 if they hit the cart)
    CASE 
        WHEN hit_cart = 1 THEN FLOOR(50 + (RAND() * 250)) 
        ELSE 0 
    END AS potential_revenue
FROM funnel_flags;

/* Old Customer Segmentation Logic
SELECT 
    *,
    -- Behavioral Segmentation
    CASE 
        WHEN purchased = 1 THEN '1. Buyer'
        WHEN hit_cart = 1 THEN '2. Cart Abandoner'
        WHEN total_events >= 3 THEN '3. Window Shopper'
        ELSE '4. Bouncer / Low Intent'
    END AS customer_segment,
    
    -- Revenue Simulation (Assigns a random value between 50 and 300 if they hit the cart)
    CASE 
        WHEN hit_cart = 1 THEN FLOOR(50 + (RAND() * 250)) 
        ELSE 0 
    END AS potential_revenue
FROM funnel_flags;
*/

-- Overall conversion rate
SELECT 
    COUNT(session_id) AS total_sessions,
    SUM(purchased) AS total_purchases,
    ROUND((SUM(purchased) / COUNT(session_id)) * 100, 2) AS conversion_rate_pct
FROM master_session_summary;