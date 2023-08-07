/* 1. Продуктовые задачи */

/* 1.1. Проанализируйте, насколько быстро растёт аудитория нашего сервиса, и посмотрим на динамику числа пользователей и курьеров.
Задание:
Для каждого дня, представленного в таблицах user_actions и courier_actions, рассчитайте следующие показатели:
- Число новых пользователей.
- Число новых курьеров.
- Общее число пользователей на текущий день.
- Общее число курьеров на текущий день. */

WITH sq1 AS (SELECT time,
                    user_id,
                    MIN(time) OVER (PARTITION BY user_id) AS user_first_day,
                    courier_id,
                    MIN(time) OVER (PARTITION BY courier_id) AS courier_first_day
             FROM   user_actions
		    FULL JOIN courier_actions USING(time))
SELECT date,
       new_users,
       new_couriers,
       (SUM(new_users) OVER (ORDER BY date))::INT AS total_users,
       (SUM(new_couriers) OVER (ORDER BY date))::INT AS total_couriers
FROM   (SELECT time::date AS date,
               COUNT(DISTINCT user_id) filter (WHERE time = user_first_day) AS new_users,
               COUNT(DISTINCT courier_id) filter (WHERE time = courier_first_day) AS new_couriers
        FROM   sq1
        GROUP BY date) AS sq2;

______________________________________

/* 1.2. Подсчитайте динамику показателей из задания 1.1 в относительных величинах.
Задание:
Дополните запрос из предыдущего задания и теперь для каждого дня, представленного в таблицах user_actions и courier_actions, дополнительно рассчитайте следующие показатели:
-Прирост числа новых пользователей.
-Прирост числа новых курьеров.
-Прирост общего числа пользователей.
-Прирост общего числа курьеров.
-Показатели, рассчитанные на предыдущем шаге, также включите в результирующую таблицу. */

WITH sq1 AS (SELECT time,
                    user_id,
                    MIN(time) OVER (PARTITION BY user_id) AS user_first_day,
                    courier_id,
                    MIN(time) OVER (PARTITION BY courier_id) AS courier_first_day
             FROM   user_actions
		    FULL JOIN courier_actions USING(time)),
sq2 AS (SELECT    time::DATE as date,
                  COUNT(DISTINCT user_id) filter (WHERE time = user_first_day) AS new_users,
                  COUNT(DISTINCT courier_id) filter (WHERE time = courier_first_day) AS new_couriers
        FROM      sq1
        GROUP BY  date)
SELECT date,
       new_users,
       new_couriers,
       total_users,
       total_couriers,
       round(100 * (new_users::decimal - new_users_lag) / new_users_lag, 2) AS new_users_change,
       round(100 * (new_couriers::decimal - new_couriers_lag) / new_couriers_lag, 2) AS new_couriers_change,
       round(100 * (total_users::decimal - lag(total_users) OVER (ORDER BY date)) / lag(total_users) OVER (ORDER BY date), 2) AS total_users_growth,
       round(100 * (total_couriers::decimal - lag(total_couriers) OVER (ORDER BY date)) / lag(total_couriers) OVER (ORDER BY date), 2) AS total_couriers_growth
FROM   (SELECT date,
               new_users,
               new_couriers,
               (SUM(new_users) OVER (ORDER BY date))::INT AS total_users,
               (SUM(new_couriers) OVER (ORDER BY date))::INT AS total_couriers,
               LAG(new_users) OVER (ORDER BY date) AS new_users_lag,
               LAG(new_couriers) OVER (ORDER BY date) AS new_couriers_lag
        FROM   sq2) AS sq3;

______________________________________
		
/* 1.3. Задание:
Для каждого дня, представленного в таблицах user_actions и courier_actions, рассчитайте следующие показатели:
- Число платящих пользователей.
- Число активных курьеров.
- Долю платящих пользователей в общем числе пользователей на текущий день.
- Долю активных курьеров в общем числе курьеров на текущий день. */

WITH sq1 AS (SELECT
                time,
                user_id,
                user_actions.order_id AS user_order_id,
                MIN(time) OVER (PARTITION BY user_id) AS user_first_day,
                courier_id,
                courier_actions.order_id AS courier_order_id,
                courier_actions.action AS courier_action,
                MIN(time) OVER (PARTITION BY courier_id) AS courier_first_day
             FROM
                user_actions
                FULL JOIN courier_actions USING(time)),
sq2 AS (SELECT
            time::DATE AS date,
            COUNT(DISTINCT user_id) FILTER (WHERE time = user_first_day) AS new_users,
            COUNT(DISTINCT user_id) FILTER (WHERE user_order_id NOT IN (SELECT order_id
									FROM user_actions
									WHERE action = 'cancel_order')) AS paying_users,
            COUNT(DISTINCT courier_id) FILTER (WHERE time = courier_first_day) AS new_couriers,
            COUNT(DISTINCT courier_id) FILTER (WHERE (courier_action = 'accept_order'
						      AND
						      courier_order_id IN (SELECT order_id
									   FROM courier_actions
									   WHERE action ='deliver_order')
						      )
						      OR courier_action = 'deliver_order') AS active_couriers
        FROM
            sq1
        GROUP BY
            date)
SELECT
    date,
    paying_users,
    ROUND(100 * paying_users::DECIMAL / total_users, 2) AS paying_users_share,
    active_couriers,
    ROUND(100 * active_couriers::DECIMAL / total_couriers, 2) AS active_couriers_share
FROM
    (SELECT
        date,
        (SUM(new_users) OVER (ORDER BY date))::INT AS total_users,
        (SUM(new_couriers) OVER (ORDER BY date))::INT AS total_couriers,
        paying_users,
        active_couriers
    FROM
        sq2) AS sq3;

______________________________________

/* 1.4. Необходимо выяснить, как много платящих пользователей совершают более одного заказа в день.
Задание:
Для каждого дня, представленного в таблице user_actions, рассчитайте следующие показатели:
- Долю пользователей, сделавших в этот день всего один заказ, в общем количестве платящих пользователей.
- Долю пользователей, сделавших в этот день несколько заказов, в общем количестве платящих пользователей. */

WITH sq1 AS (SELECT
                time::DATE AS date,
                user_id,
                COUNT(DISTINCT order_id) AS count_orders
            FROM
                user_actions
            WHERE
                order_id NOT IN (SELECT order_id
				 FROM user_actions
				 WHERE action = 'cancel_order')
            GROUP BY
                date,
                user_id)
SELECT
    date,
    ROUND(100 * single_order_users::DECIMAL / total_users_by_day, 2) AS single_order_users_share,
    ROUND(100 * several_order_users::DECIMAL / total_users_by_day, 2) AS several_orders_users_share
FROM
    (SELECT
        date,
        COUNT(user_id) FILTER (WHERE count_orders = 1) AS single_order_users,
        COUNT(user_id) FILTER (WHERE count_orders > 1) AS several_order_users,
        COUNT(user_id) AS total_users_by_day
    FROM
        sq1
    GROUP BY
        date) AS sq2
ORDER BY
    date;

______________________________________

/* 1.5*. Задание:
Для каждого дня, представленного в таблице user_actions, рассчитайте следующие показатели:
- Общее число заказов.
- Число первых заказов (заказов, сделанных пользователями впервые).
- Число заказов новых пользователей (заказов, сделанных пользователями в тот же день, когда они впервые воспользовались сервисом).
- Долю первых заказов в общем числе заказов (долю п.2 в п.1).
- Долю заказов новых пользователей в общем числе заказов (долю п.3 в п.1). */

WITH sq1 AS (SELECT	
		time::DATE AS date,
		user_id,
		order_id,
		(MIN(time) OVER (PARTITION BY user_id))::DATE AS user_first_day,
		CASE
		WHEN order_id IN (SELECT MIN(order_id)
				  FROM user_actions
				  WHERE order_id NOT IN (SELECT order_id
							 FROM user_actions
							 WHERE action = 'cancel_order')
				  GROUP BY user_id) THEN 'first_order'
		END AS user_first_order,
		CASE
		WHEN time::DATE = (MIN(time) OVER (PARTITION BY user_id))::DATE THEN 'order_as_new_user'
		END AS orders_as_new_user
	    FROM
		user_actions)
SELECT  
	date,
	total_orders_by_day AS orders,
	first_orders,
	new_users_orders,
	ROUND(100 * first_orders::DECIMAL / total_orders_by_day, 2) AS first_orders_share,
	ROUND(100 * new_users_orders::DECIMAL / total_orders_by_day, 2) AS new_users_orders_share
FROM
	(SELECT  
		date,
		COUNT(DISTINCT order_id) AS total_orders_by_day,
		COUNT(DISTINCT order_id) FILTER (WHERE user_first_order = 'first_order') AS first_orders,
		COUNT(DISTINCT order_id) FILTER (WHERE orders_as_new_user = 'order_as_new_user') AS new_users_orders
	FROM    
		sq1
	WHERE	
		order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
	GROUP BY
		date) AS sq2
ORDER BY  date;

______________________________________

/* 1.6. Необходимо оценить нагрузку на наших курьеров и узнать сколько в среднем заказов и пользователей приходится на каждого из них.
Задание:
На основе данных в таблицах user_actions, courier_actions и orders для каждого дня рассчитайте следующие показатели:
- Число платящих пользователей на одного активного курьера.
- Число заказов на одного активного курьера. */

WITH sq1 AS (SELECT time,
                    user_id,
                    user_actions.order_id AS user_order_id,
                    courier_id,
                    courier_actions.order_id AS courier_order_id,
                    courier_actions.action AS courier_action
             FROM   user_actions
		    FULL JOIN courier_actions USING(time)),
sq2 AS (SELECT 
		time::DATE AS date,
                COUNT(DISTINCT user_id) FILTER (WHERE user_order_id NOT IN (SELECT order_id
		 							    FROM   user_actions
                                                                            WHERE  action = 'cancel_order')) AS paying_users,
		COUNT(DISTINCT courier_id) FILTER (WHERE  (courier_action = 'accept_order' 
							   AND
							   courier_order_id IN (SELECT order_id
                                                                                FROM   courier_actions
                                                                                WHERE  action = 'deliver_order')
							   )
                                                          OR courier_action = 'deliver_order') AS active_couriers,
		 COUNT(DISTINCT user_order_id) FILTER (WHERE  user_order_id NOT IN (SELECT order_id
                                                                                    FROM   user_actions
                                                                                    WHERE  action = 'cancel_order')) AS total_orders
        FROM   
		sq1
        GROUP BY
		date)

SELECT 
	date,
       	ROUND(paying_users::DECIMAL / active_couriers, 2) AS users_per_courier ,
       	ROUND(total_orders::decimal / active_couriers, 2) AS orders_per_courier
FROM   
	sq2;

______________________________________

/* 1.7.
Задание:
На основе данных в таблице courier_actions для каждого дня рассчитайте, за сколько минут в среднем курьеры доставляли свои заказы. */

SELECT time::DATE AS date,
       ROUND(AVG((EXTRACT(EPOCH FROM finish) - EXTRACT(EPOCH FROM start))/60)) AS minutes_to_deliver
FROM   (SELECT time,
               order_id,
               MIN(time) OVER (PARTITION BY order_id) AS start,
               MAX(time) OVER (PARTITION BY order_id) AS finish
        FROM   courier_actions
        WHERE  order_id NOT IN (SELECT order_id
                                FROM   user_actions
                                WHERE  action = 'cancel_order')) AS sq1
GROUP BY date
ORDER BY date;

______________________________________

/* 1.8. Оценим почасовую нагрузку на сервис.
Задача:
На основе данных в таблице orders для каждого часа в сутках рассчитайте следующие показатели:
- Число успешных (доставленных) заказов.
- Число отменённых заказов.
- Долю отменённых заказов в общем числе заказов (cancel rate). */

WITH sq1 AS (SELECT
                DATE_PART('hour', creation_time)::INT AS hour,
                COUNT(order_id) AS total_orders_by_hour,
                COUNT(order_id) FILTER (WHERE order_id IN (SELECT order_id FROM courier_actions WHERE action = 'deliver_order')) AS successful_orders,
                COUNT(order_id) FILTER (WHERE order_id IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) AS canceled_orders
            FROM
                orders
            GROUP BY
                DATE_PART('hour', creation_time))
SELECT
    hour,
    successful_orders,
    canceled_orders,
    ROUND(canceled_orders::DECIMAL / total_orders_by_hour, 3) AS cancel_rate
FROM
    sq1
ORDER BY
    hour;
