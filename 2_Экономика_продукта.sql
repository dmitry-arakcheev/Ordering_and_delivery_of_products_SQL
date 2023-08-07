/* 2. Экономика продукта */

/* 2.1.
Задание:
Для каждого дня в таблице orders рассчитайте следующие показатели:
- Выручку, полученную в этот день.
- Суммарную выручку на текущий день.
- Прирост выручки, полученной в этот день, относительно значения выручки за предыдущий день. */

WITH sq1 AS (SELECT
                creation_time,
                order_id ,
                UNNEST(product_ids) AS product_id
            FROM
                orders
            WHERE
                order_id NOT IN (SELECT order_id
                                        FROM user_actions
                                        WHERE action = 'cancel_order')),
sq2 AS (SELECT 
            creation_time,
            order_id ,
            product_id,
            price   
        FROM
            sq1
            INNER JOIN products USING(product_id))
SELECT
    date,
    revenue,
    SUM(revenue) OVER(ORDER BY date) AS total_revenue,
    ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY date))::DECIMAL / LAG(revenue) OVER (ORDER BY date), 2) AS revenue_change
FROM
    (SELECT
        creation_time::date AS date,
        SUM(price) AS revenue
    FROM
        sq2
    GROUP BY
        creation_time::date) AS sq3;

______________________________________

/* 2.2. Теперь на основе данных о выручке для каждого дня в таблицах orders и user_actions рассчитайте следующие показатели:
- Выручку на пользователя (ARPU) за текущий день.
- Выручку на платящего пользователя (ARPPU) за текущий день.
- Выручку с заказа, или средний чек (AOV) за текущий день. */

WITH sq1 AS (SELECT
                creation_time,
                order_id ,
                UNNEST(product_ids) AS product_id
            FROM
                orders
            WHERE
                order_id NOT IN (SELECT order_id
                                        FROM user_actions
                                        WHERE action = 'cancel_order')),
sq2 AS (SELECT 
            creation_time,
            order_id ,
            product_id,
            price   
        FROM
            sq1
            INNER JOIN products USING(product_id))
SELECT
    date,
    ROUND(revenue::DECIMAL / total_orders_per_day, 2) AS aov,
    ROUND(revenue::DECIMAL / total_users_per_day, 2) AS arpu,
    ROUND(revenue::DECIMAL / total_paying_users_per_day, 2) AS arppu
FROM
    (SELECT
        creation_time::date AS date,
        SUM(price) AS revenue
    FROM
        sq2
    GROUP BY
        creation_time::date) AS sq3
    INNER JOIN
    (SELECT
        time::DATE AS date,
        COUNT(DISTINCT order_id) FILTER (WHERE order_id NOT IN (SELECT order_id
                                                                FROM user_actions
                                                                WHERE action = 'cancel_order')) AS total_orders_per_day,
        COUNT(DISTINCT user_id) FILTER (WHERE order_id NOT IN (SELECT order_id
                                                                FROM user_actions
                                                                WHERE action = 'cancel_order')) AS total_paying_users_per_day,
        COUNT(DISTINCT user_id) AS total_users_per_day
    FROM
        user_actions
    GROUP BY
        date) AS sq4 USING (date)
ORDER BY
    date;

______________________________________

/* 2.3* Необходимо вычислить все те же метрики, но для каждого дня учитывать накопленную выручку и все имеющиеся на текущий момент данные о числе пользователей и заказов. 
Задание:
По таблицам orders и user_actions для каждого дня рассчитайте следующие показатели:
- Накопленную выручку на пользователя (Running ARPU).
- Накопленную выручку на платящего пользователя (Running ARPPU).
- Накопленную выручку с заказа, или средний чек (Running AOV). */

WITH sq2 AS (SELECT 
                creation_time::DATE AS date,
                order_id ,
                product_id,
                price   
            FROM
                products
                INNER JOIN (SELECT
                                creation_time,
                                order_id,
                                UNNEST(product_ids) AS product_id
                            FROM
                                orders
                            WHERE
                                order_id NOT IN (SELECT order_id
                                                 FROM user_actions
                                                 WHERE action = 'cancel_order')) AS sq1 USING(product_id)),
sq3 AS (SELECT time::DATE AS date,
               user_id,
               (MIN(time) OVER (PARTITION BY user_id))::DATE AS user_first_day,
               order_id
        FROM   user_actions
        WHERE order_id NOT IN (SELECT order_id
                               FROM   user_actions
                               WHERE  action = 'cancel_order')),
sq4 AS (SELECT time::DATE AS date,
               user_id,
               (MIN(time) OVER (PARTITION BY user_id))::DATE AS user_first_day,
               order_id
        FROM   user_actions)

SELECT
    date,
    ROUND((SUM(revenue) OVER (ORDER BY date))::DECIMAL / SUM(new_users) OVER (ORDER BY date), 2) AS Running_ARPU,
    ROUND((SUM(revenue) OVER (ORDER BY date))::DECIMAL / SUM(paying_users) OVER (ORDER BY date), 2) AS Running_ARPPU,
    ROUND((SUM(revenue) OVER (ORDER BY date))::DECIMAL / SUM(total_orders_per_day) OVER (ORDER BY date), 2) AS Running_AOV
FROM
    (SELECT
        date,
        SUM(price) AS revenue
    FROM
        sq2
    GROUP BY
        date) AS sq5
    INNER JOIN
    (SELECT date,
            COUNT(DISTINCT order_id) AS total_orders_per_day,
            COUNT(DISTINCT user_id) filter (WHERE date = user_first_day) AS paying_users
     FROM
         sq3
     GROUP BY
         date) AS sq6 USING (date)
    INNER JOIN 
    (SELECT date,
            COUNT(DISTINCT user_id) filter (WHERE date = user_first_day) AS new_users
     FROM
         sq4
     GROUP BY
         date) AS sq7 USING (date)
ORDER BY
    date;
	
______________________________________

/* 2.4. Посчитайте те же показатели, но в другом разрезе (по дням недели).
Задание:
Для каждого дня недели в таблицах orders и user_actions рассчитайте следующие показатели:
- Выручку на пользователя (ARPU).
- Выручку на платящего пользователя (ARPPU).
- Выручку на заказ (AOV). */

WITH sq1 AS (SELECT
                creation_time,
                order_id ,
                UNNEST(product_ids) AS product_id
            FROM
                orders
            WHERE
                order_id NOT IN (SELECT order_id
                                        FROM user_actions
                                        WHERE action = 'cancel_order')
                AND creation_time BETWEEN '2022-08-26' AND '2022-09-09'),
sq2 AS (SELECT 
            creation_time,
            order_id ,
            product_id,
            price   
        FROM
            sq1
            INNER JOIN products USING(product_id))
SELECT
    weekday,
    weekday_number,
    ROUND(revenue / total_orders_per_day, 2) AS aov,
    ROUND(revenue / total_users_per_day, 2) AS arpu,
    ROUND(revenue / total_paying_users_per_day, 2) AS arppu
FROM
    (SELECT
        to_char(creation_time, 'Day') AS weekday,
        DATE_PART('isodow', creation_time) AS weekday_number,
        COUNT(DISTINCT order_id) AS total_orders_per_day,
        SUM(price) AS revenue
    FROM
        sq2
    GROUP BY
        weekday,
        weekday_number) AS sq3
    INNER JOIN
    (SELECT
        to_char(time, 'Day') AS weekday,
        COUNT(DISTINCT user_id) FILTER (WHERE order_id NOT IN (SELECT order_id
                                                                FROM user_actions
                                                                WHERE action = 'cancel_order')) AS total_paying_users_per_day,
        COUNT(DISTINCT user_id) AS total_users_per_day
    FROM
        user_actions
    WHERE
        time BETWEEN '2022-08-26' AND '2022-09-09'
    GROUP BY
        weekday) AS sq4 USING (weekday)
ORDER BY
    weekday_number;

______________________________________

/* 2.5. Продолжаем усложнять запрос.
Задание:
Для каждого дня в таблицах orders и user_actions рассчитайте следующие показатели:
- Выручку, полученную в этот день.
- Выручку с заказов новых пользователей, полученную в этот день.
- Долю выручки с заказов новых пользователей в общей выручке, полученной за этот день.
- Долю выручки с заказов остальных пользователей в общей выручке, полученной за этот день. */

WITH orders_products_prices AS (SELECT 
                                    creation_time::DATE AS date,
                                    order_id ,
                                    product_id,
                                    price   
                                FROM
                                    products
                                    INNER JOIN (SELECT
                                                    creation_time,
                                                    order_id,
                                                    UNNEST(product_ids) AS product_id
                                                FROM
                                                    orders
                                                WHERE
                                                    order_id NOT IN (SELECT order_id
                                                                     FROM user_actions
                                                                     WHERE action = 'cancel_order')) AS sq1 USING(product_id)),
users_first_day AS (SELECT time::DATE AS date,
                           user_id,
                           (MIN(time) OVER (PARTITION BY user_id))::DATE as user_first_day,
                           order_id
                    FROM   user_actions)

SELECT
    date,
    revenue,
    new_users_revenue,
    ROUND(100 * new_users_revenue / revenue::DECIMAL, 2) AS new_users_revenue_share,
    ROUND(100 *(1 - new_users_revenue / revenue::DECIMAL), 2) AS old_users_revenue_share
FROM
    (SELECT 
        date,
        SUM(price) AS revenue,
        SUM(price) FILTER (WHERE date = user_first_day) AS new_users_revenue
    FROM
        orders_products_prices
        INNER JOIN users_first_day USING (date, order_id)
    GROUP BY
        date) AS date_revenue_new_users;

______________________________________

/* 2.6. Какие товары пользуются наибольшим спросом и приносят основной доход?
Задание:
Для каждого товара, представленного в таблице products, за весь период времени в таблице orders рассчитайте следующие показатели:
- Суммарную выручку, полученную от продажи этого товара за весь период.
- Долю выручки от продажи этого товара в общей выручке, полученной за весь период. */

WITH sq1 AS (SELECT 
                UNNEST(product_ids) AS product_id
             FROM
                orders
             WHERE
                order_id NOT IN (SELECT  order_id
                                 FROM    user_actions 
                                 WHERE   action = 'cancel_order')),
sq2 AS (SELECT 
            name,
            price,
            product_id
        FROM
            products),
sq3 AS (SELECT
	    name,
 	    SUM(price) AS revenue
	FROM
	   sq1
	   INNER JOIN sq2 USING (product_id)
	GROUP BY
	   name)

SELECT
    product_name,
    SUM(revenue) AS revenue,
    SUM(share_in_revenue) AS share_in_revenue
FROM
    (SELECT
        CASE
        WHEN ROUND(100 * revenue / SUM(revenue) OVER(), 2) < 0.5 THEN 'ДРУГОЕ'
        ELSE name
        END AS product_name,
        revenue,
        ROUND(100 * revenue / SUM(revenue) OVER(), 2) AS share_in_revenue
    FROM
        sq3) AS sq4
GROUP BY
    product_name
ORDER BY
    revenue DESC;
	
______________________________________

/* 2.7*. Попробуем учесть в наших расчётах затраты с налогами и посчитаем валовую прибыль.
Задание:
Для каждого дня в таблицах orders и courier_actions рассчитайте следующие показатели:
- Выручку, полученную в этот день.
- Затраты, образовавшиеся в этот день.
- Сумму НДС с продажи товаров в этот день.
- Валовую прибыль в этот день (выручка за вычетом затрат и НДС).
- Суммарную выручку на текущий день.
- Суммарные затраты на текущий день.
- Суммарный НДС на текущий день.
- Суммарную валовую прибыль на текущий день.
- Долю валовой прибыли в выручке за этот день (долю п.4 в п.1).
- Долю суммарной валовой прибыли в суммарной выручке на текущий день (долю п.8 в п.5). */

WITH orders_products_prices AS (SELECT 
                                    creation_time::DATE AS date,
                                    order_id ,
                                    product_id,
                                    name,
                                    price,
                                    CASE
                                    WHEN name IN ('сахар', 'сухарики', 'сушки', 'семечки', 
                                                  'масло льняное', 'виноград', 'масло оливковое', 
                                                  'арбуз', 'батон', 'йогурт', 'сливки', 'гречка', 
                                                  'овсянка', 'макароны', 'баранина', 'апельсины', 
                                                  'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 
                                                  'мука', 'шпроты', 'сосиски', 'свинина', 'рис', 
                                                  'масло кунжутное', 'сгущенка', 'ананас', 'говядина', 
                                                  'соль', 'рыба вяленая', 'масло подсолнечное', 'яблоки', 
                                                  'груши', 'лепешка', 'молоко', 'курица', 'лаваш', 'вафли', 'мандарины') THEN ROUND(10 * price / 110, 2)
                                    ELSE ROUND(20 * price / 120, 2)
                                    END AS nds
                                FROM
                                    products
                                    INNER JOIN (SELECT
                                                    creation_time,
                                                    order_id,
                                                    UNNEST(product_ids) AS product_id
                                                FROM
                                                    orders
                                                WHERE
                                                    order_id NOT IN (SELECT order_id
                                                                     FROM user_actions
                                                                     WHERE action = 'cancel_order')) AS sq1 USING(product_id)),
fixed_costs_plus_orders_piking AS (SELECT
                                        date,
                                        CASE
                                        WHEN EXTRACT(MONTH FROM date) = 8 THEN 120000 + 140 * orders_per_day
                                        WHEN EXTRACT(MONTH FROM date) = 9 THEN 150000 + 115 * orders_per_day
                                        END AS fixed_costs_plus_ord
                                    FROM
                                        (SELECT
                                                creation_time::DATE AS date,
                                                COUNT(order_id) AS orders_per_day
                                         FROM
                                                orders
                                         WHERE
                                                order_id NOT IN (SELECT order_id
                                                                 FROM user_actions
                                                                 WHERE action = 'cancel_order')
                                         GROUP BY
                                                date) AS date_orders),
coasts_couriers AS (SELECT
                        date,
                        SUM(delivered_orders) * 150 AS delivery_costs,
                        SUM(daily_bonus) AS bonuses_costs
                    FROM
                        (SELECT
                            time::DATE as date,
                            courier_id,
                            COUNT(order_id) AS delivered_orders,
                            CASE
                            WHEN COUNT(order_id) >=5 AND EXTRACT(MONTH FROM time::DATE) = 8 THEN 400
                            WHEN COUNT(order_id) >=5 AND EXTRACT(MONTH FROM time::DATE) = 9 THEN 500
                            ELSE 0
                            END AS daily_bonus
                        FROM
                            courier_actions
                        WHERE
                            action = 'deliver_order'
                        GROUP BY
                            date,
                            courier_id) AS date_couriers
                    GROUP BY
                        date),
revenue_tab AS (SELECT 
                    date,
                    SUM(price) AS revenue,
                    SUM(nds) AS tax
                FROM
                    orders_products_prices
                GROUP BY
                    date)

SELECT
    date,
    revenue,
    costs,
    tax,
    gross_profit,
    SUM(revenue) OVER(ORDER BY date) AS total_revenue,
    (SUM(costs) OVER(ORDER BY date))::DECIMAL AS total_costs,
    SUM(tax) OVER(ORDER BY date) AS total_tax,
    SUM(gross_profit) OVER(ORDER BY date) AS total_gross_profit,
    ROUND(100 * gross_profit / revenue, 2) AS gross_profit_ratio,
    ROUND(100 * SUM(gross_profit) OVER(ORDER BY date) / SUM(revenue) OVER(ORDER BY date), 2) AS total_gross_profit_ratio
FROM
    (SELECT
        date,
        revenue,
        (fixed_costs_plus_ord  + delivery_costs + bonuses_costs)::INT AS costs,
        tax,
        (revenue - tax - (fixed_costs_plus_ord  + delivery_costs + bonuses_costs)) AS gross_profit
    FROM
        revenue_tab
        INNER JOIN fixed_costs_plus_orders_piking USING (date)
        INNER JOIN coasts_couriers USING (date)) AS revenue_costs_tax_profit;

______________________________________
