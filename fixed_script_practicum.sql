/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Алина
 * Дата: 20.03.2025 (правки от 25.03)
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков		

-- 1.1. Доля платящих пользователей по всем данным (исправленный запрос):
SELECT 
	count (payer) AS total_users,
	sum (payer) AS payers,
	round(avg(payer), 4) AS payers_share
FROM fantasy.users u 


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
    r.race,
    COUNT(u.id) AS users,
    SUM(u.payer) AS payers,
    round(avg(u.payer), 4) AS payers_share
FROM fantasy.users u
LEFT JOIN fantasy.race r USING (race_id) 
GROUP BY r.race
ORDER BY payers_share DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT 
count(transaction_id) AS total_purchase, -- Общее кол-во покупок
sum(amount) AS total_amount, -- Общая сумма покупок
round(min(amount::NUMERIC),4) AS min_cost, -- Минимальная стоимость покупки
round(max(amount::NUMERIC),4) AS max_cost, -- Максимальная стоимость покупки
round(avg(amount::NUMERIC),4) AS avg_costs, -- Средняя стоимость покупки
round(percentile_disc(0.5) WITHIN GROUP (ORDER BY amount::NUMERIC),4) AS mediana, -- Медиана
round(stddev(amount::NUMERIC),4) AS stddev_amount -- Стандартное отклонение стоимости покупки
FROM fantasy.events e 
WHERE amount > 0

-- Сравнительный анализ (совмещение рез-ов с нулевыми покупками)
SELECT 
    COUNT(transaction_id) AS total_purchase, 
    SUM(amount) AS total_amount, 
    ROUND(MIN(amount::NUMERIC), 4) AS min_cost, 
    ROUND(MAX(amount::NUMERIC), 4) AS max_cost, 
    ROUND(AVG(amount::NUMERIC), 4) AS avg_costs, 
    ROUND(percentile_disc(0.5) WITHIN GROUP (ORDER BY amount::NUMERIC), 4) AS mediana, 
    ROUND(STDDEV(amount::NUMERIC), 4) AS stddev_amount 
FROM 
    fantasy.events e 
UNION ALL
SELECT 
    COUNT(transaction_id) AS total_purchase, 
    SUM(amount) AS total_amount, 
    ROUND(MIN(amount::NUMERIC), 4) AS min_cost, 
    ROUND(MAX(amount::NUMERIC), 4) AS max_cost, 
    ROUND(AVG(amount::NUMERIC), 4) AS avg_costs, 
    ROUND(percentile_disc(0.5) WITHIN GROUP (ORDER BY amount::NUMERIC), 4) AS mediana, 
    ROUND(STDDEV(amount::NUMERIC), 4) AS stddev_amount 
FROM 
    fantasy.events e 
WHERE 
    amount > 0

-- 2.2: Аномальные нулевые покупки:
SELECT 	count(amount) AS total_amount,
		count(CASE WHEN amount = 0 THEN amount END) AS null_purchase,
		round(count(CASE WHEN amount = 0 THEN amount END) * 100 / count(amount::float), 4) AS dolya
FROM fantasy.events e

-- Считаем, какие пользователи генерируют нулевые покупки:
WITH null_purchases AS (
-- Вычисляем всех пользователей, совершивших нулевые покупки
SELECT u3.id AS users,
	u3.tech_nickname,
	count(e4.transaction_id) AS null_purchases
FROM fantasy.users u3 
JOIN fantasy.events e4 USING (id)
WHERE e4.amount = 0
GROUP BY users
ORDER BY null_purchases DESC
), 
total_null_purchases AS (
-- Считаем общее кол-во нулевых покупок
SELECT 
	count(e.transaction_id) AS total_null_purchases
FROM fantasy.events e 
WHERE e.amount = 0
)
SELECT 
	users, 
	tech_nickname,
	null_purchases,
	round(null_purchases::NUMERIC / total_null_purchases, 4) AS null_purchases_share
FROM null_purchases, total_null_purchases
ORDER BY null_purchases DESC;

-- Изучаем аккаунт с наибольшим кол-вом нулевых покупок - MajesticGuardian6128:
WITH null_purchases as(
SELECT id, 
	count(e.transaction_id) AS null_purchases
FROM fantasy.users u 
JOIN fantasy.events e USING (id)
WHERE tech_nickname = 'MajesticGuardian6128' AND e.amount = 0
GROUP BY id
)
SELECT u.id, 
	tech_nickname,
	count(transaction_id) AS num_purchases, -- Считаем все покупки
	null_purchases, -- Нулевые покупки
	(count(transaction_id) - null_purchases) AS paid_purchases, -- Исключаем нулевые покупки
	round(sum(amount::NUMERIC), 4) AS sum_purchases -- Общая сумма покупок
FROM fantasy.users u 
JOIN fantasy.events e USING (id)
JOIN null_purchases np USING (id)
WHERE tech_nickname = 'MajesticGuardian6128' 
GROUP BY u.id, null_purchases

-- Альтернативный запрос с FILTER:
SELECT COUNT(*) AS count_pay,
       COUNT(*) FILTER (WHERE amount = 0) count_null_pay,
       COUNT(*) FILTER (WHERE amount = 0) / COUNT(*)::FLOAT AS percent_pay
FROM fantasy.events e


-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

-- Скорректированный запрос:
SELECT payer, 
		count(id) AS total_payers, -- Убираем DISTINCT
		SUM(total_orders) AS total_transactions, -- Общее кол-во покупок
		ROUND(AVG(total_orders)::NUMERIC, 2) AS avg_num_transaction_user,
    	ROUND(AVG(total_amount)::NUMERIC, 2) AS avg_sum_transaction_user
FROM ( 
	-- Статистика по игрокам
	SELECT 
	u2.id, 
	CASE WHEN payer = 1 THEN 'Платящий' ELSE 'Неплатящий' END AS payer,
	count(*) AS total_orders,
	sum(amount) AS total_amount
	FROM fantasy.users u2 
	LEFT JOIN fantasy.events e3 USING (id)
	WHERE amount <> 0 
	GROUP BY id, payer) AS subquery
GROUP BY payer

-- Исследование по всем зарегистрированным пользователям:
SELECT
    payer,
    COUNT(id) AS total_users,
    ROUND(AVG(total_orders)::NUMERIC, 2) AS avg_num_transaction_user,
    ROUND(AVG(sum_amount)::NUMERIC, 2) AS avg_sum_transaction_user
FROM (
    SELECT
        u.id, 
        CASE WHEN payer = 1 THEN 'Платящий' ELSE 'Неплатящий' END AS payer,
        COUNT(*) AS total_orders,
        COALESCE(SUM(amount), 0) AS sum_amount -- для игроков без покупок ставим 0
    FROM fantasy.users AS u
    LEFT JOIN (SELECT * FROM fantasy.events WHERE amount <> 0) AS e ON u.id=e.id
    GROUP BY u.id, payer) subq
GROUP BY payer; 

-- 2.4: Популярные эпические предметы:

WITH total_payers AS (
    SELECT COUNT(DISTINCT id) AS total_payers
    FROM fantasy.users
)
SELECT i.game_items, 
	count(transaction_id) AS total_sales,
	ROUND(COUNT(e.transaction_id) * 100.0 / SUM(COUNT(e.transaction_id)) OVER(), 2) AS relative_sales,
	count(DISTINCT e.id) AS unique_users,
	count(DISTINCT e.id)* 100 / tp.total_payers AS user_share
FROM fantasy.events e 
JOIN fantasy.items i using(item_code)
CROSS JOIN total_payers tp
WHERE amount > 0 -- Добавлен фильтр нулевых покупок
GROUP BY i.game_items, tp.total_payers
ORDER BY total_sales desc

-- Часть 2. Решение ad hoc-задач

-- Задача 1. Зависимость активности игроков от расы персонажа:

-- Зависимость активности игроков от расы персонажа (исправленный запрос):
WITH gamers_stat AS (
-- Считаем статистику игроков по расе
    SELECT
        u.race_id,
        COUNT(u.id) AS total_gamers
    FROM
        fantasy.users u
    GROUP BY
        u.race_id
),
buyers_stat AS (
-- Считаем платящих игроков, их долю и исключаем нулевые покупки
    SELECT
    	u.race_id,
    	COUNT(DISTINCT CASE WHEN e.amount > 0 THEN u.id END) AS buyers, -- кол-во плательщиков
	    COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS payers, -- кол-во плательщиков
	    ROUND(COUNT(DISTINCT CASE WHEN e.amount > 0 THEN u.id END)::NUMERIC / COUNT(DISTINCT u.id), 4) AS buyers_share,  -- доля покупателей от всех игроков
	    ROUND(COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END)::NUMERIC / COUNT(DISTINCT u.id), 4) AS payers_share -- доля платящих игроков
    FROM
        fantasy.users u
    JOIN
        fantasy.events e ON u.id = e.id
    WHERE
        e.amount <> 0
    GROUP BY
        u.race_id
),
orders_stat AS (
-- Статистика по транзакциям, исключаем нулевые покупки
    SELECT
        u.race_id,
        COUNT(e.transaction_id) AS total_orders,
        SUM(e.amount) AS total_amount
    FROM
        fantasy.users u
    JOIN
        fantasy.events e ON u.id = e.id
    WHERE
        e.amount > 0
    GROUP BY
        u.race_id
)
SELECT
-- Статистика по игрокам:
    r.race,
    gs.total_gamers, -- Все зарегистрированные игроки
    bs.buyers, -- Все покупатели 
    bs.payers, -- Все платящие игроки
    ROUND(bs.buyers::NUMERIC / gs.total_gamers, 4) AS buyers_share, -- Доля покупателей среди всех игроков
    bs.payers_share, -- Доля плательщиков среди всех игроков
-- Статистика по покупкам:
    ROUND(os.total_orders::NUMERIC / bs.buyers, 2) AS orders_per_buyer, -- Срденее кол-во покупок на игрока
    ROUND(os.total_amount::NUMERIC / bs.buyers, 2) AS total_amount_per_buyer, -- Средняя сумма, потраченная игроком
    ROUND(os.total_amount::NUMERIC / os.total_orders, 2) AS avg_amount_per_buyer -- Средняя сумма одной покупки
FROM
    gamers_stat gs
    JOIN buyers_stat bs USING (race_id)
    JOIN orders_stat os USING (race_id)
    JOIN fantasy.race r USING (race_id)
ORDER BY
    buyers_share DESC;
  

-- Задача 2: Частота покупок
-- Высчитываем интервал между покупками по каждому пользователю, убираем покупки с нулевой стоимостью
WITH purchases_with_intervals AS (
    SELECT 
        id,
        transaction_id,
        u.payer,
        count(transaction_id) over(PARTITION BY id) AS total_per_user,
        CAST(date AS date) AS purchase_date,
        CAST(date AS date) - CAST(LAG(CAST(date AS date)) OVER (PARTITION BY id ORDER BY CAST(date AS date)) AS date) AS interval_days
    FROM 
         fantasy.events e2
    JOIN fantasy.users u using(id)
    WHERE 
        amount > 0
), 
-- Оставляем активных игроков (> 25 покупок) и считаем средний интервал между покупками
extra_data AS (
	SELECT 
		id,
	    total_per_user,
	    payer,
	    round(avg(interval_days), 2) AS avg_days_between_purchases
	FROM 
	    purchases_with_intervals
	WHERE 
		total_per_user >= 25 AND    
		interval_days IS NOT NULL AND interval_days > 0
	GROUP BY 
		payer, id, total_per_user
), 
-- Распределяем игроков на три группы, находим средний интервал в днях
ranking AS (
	SELECT 
		id,
	    total_per_user,
	    payer,
	    avg_days_between_purchases,
	    ROW_NUMBER () over(ORDER BY avg_days_between_purchases ASC) AS ranking,
	    NTILE(3) over(ORDER BY avg_days_between_purchases) AS purchasing_frequency
	FROM extra_data
),
-- Определяем кол-во игроков, которые платят
dolya AS (
	SELECT  
	purchasing_frequency,
	count(id) AS paying_payers
	FROM ranking 
	WHERE payer = 1
	GROUP BY purchasing_frequency
)
SELECT 
			CASE purchasing_frequency
	    	WHEN 1 THEN 'высокая частота'
	    	WHEN 2 THEN 'умеренная частота'
	    	WHEN 3 THEN 'низкая частота'
	    END AS frequency,
	    count(id) AS total_payers,
	    paying_payers, 
	    (paying_payers * 100 / count(id)) AS paying_share_percent,
	    AVG(total_per_user) AS avg_purchases,
	    ROUND(AVG(avg_days_between_purchases), 2) AS avg_days_between_purchases
FROM ranking
LEFT JOIN dolya USING (purchasing_frequency)
GROUP BY paying_payers, purchasing_frequency
ORDER BY purchasing_frequency





