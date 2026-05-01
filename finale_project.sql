CREATE DATABASE finale_project;
SELECT * FROM `customerinfo_final project`;
SET SQL_SAFE_UPDATES = 0;
UPDATE `customerinfo_final project` SET Age = NULL WHERE Age = '';
UPDATE `customerinfo_final project` SET Gender = NULL WHERE Gender = '';
ALTER TABLE `customerinfo_final project` MODIFY Age INT NULL; 

CREATE TABLE transactions
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL (10, 3),
Sum_payment DECIMAL (10, 2)
); 

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS_final project.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS; 

SHOW VARIABLES LIKE 'secure_file_priv';
SELECT * FROM transactions;

#1.	список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков
#за указанный годовой период, средний чек за период с 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц,
# количество всех операций по клиенту за период;

WITH monthly_data AS (
    SELECT
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS ym,
        SUM(Sum_payment) AS monthly_sum,
        COUNT(*) AS monthly_ops
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new <  '2016-06-01'
    GROUP BY ID_client, ym
),

full_year_clients AS (
    SELECT 
        ID_client
    FROM monthly_data
    GROUP BY ID_client
    HAVING COUNT(DISTINCT ym) = 12
)

SELECT
    m.ID_client,

    -- Средний чек = сумма всех покупок / количество всех операций
    SUM(m.monthly_sum) / SUM(m.monthly_ops) AS avg_check,

    -- Средняя сумма покупок в месяц
    AVG(m.monthly_sum) AS avg_monthly_sum,

    -- Количество всех операций за период
    SUM(m.monthly_ops) AS total_operations

FROM monthly_data m
JOIN full_year_clients f USING (ID_client)
GROUP BY m.ID_client
ORDER BY total_operations DESC;

2.	информацию в разрезе месяцев:
a)	средняя сумма чека в месяц;
b)	среднее количество операций в месяц;
c)	среднее количество клиентов, которые совершали операции;
d)	долю от общего количества операций за год и долю в месяц от общей суммы операций;
e)	вывести % соотношение M/F/NA в каждом месяце с их долей затрат;

#корректный код с CROSS JOIN 
WITH base AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS ym,
        t.ID_client,
        t.Sum_payment,
        c.Gender
    FROM transactions t
    LEFT JOIN `customerinfo_final project` c
        ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new <  '2016-06-01'
),

monthly AS (
    SELECT
        ym,
        COUNT(*) AS ops,
        SUM(Sum_payment) AS total_sum,
        COUNT(DISTINCT ID_client) AS clients,
        AVG(Sum_payment) AS avg_check
    FROM base
    GROUP BY ym
),

gender_month AS (
    SELECT
        ym,
        Gender,
        COUNT(*) AS ops_gender,
        SUM(Sum_payment) AS sum_gender
    FROM base
    GROUP BY ym, Gender
),

year_totals AS (
    SELECT
        SUM(ops) AS ops_year,
        SUM(total_sum) AS sum_year
    FROM monthly
)

SELECT
    m.ym,

    -- A) Средняя сумма чека в месяц
    m.avg_check,

    -- B) Среднее количество операций в месяц
    m.ops AS operations_in_month,

    -- C) Среднее количество клиентов в месяц
    m.clients AS clients_in_month,

    -- D) Доля операций и доля суммы в месяце
    m.ops / yt.ops_year AS share_ops,
    m.total_sum / yt.sum_year AS share_sum,

    -- E) Распределение M/F/NA и их доля затрат
    gm.Gender,
    gm.ops_gender,
    gm.sum_gender,
    gm.ops_gender / m.ops AS gender_ops_share,
    gm.sum_gender / m.total_sum AS gender_sum_share

FROM monthly m
CROSS JOIN year_totals yt
JOIN gender_month gm USING (ym)
ORDER BY m.ym, gm.Gender;

3.	возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации,
 с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.
 
 WITH base AS (
    SELECT
        t.ID_client,
        t.Sum_payment,
        t.date_new,
        c.Age,
        CASE
            WHEN c.Age IS NULL THEN 'NA'
            WHEN c.Age < 10 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN c.Age BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+'
        END AS age_group
    FROM transactions t
    LEFT JOIN `customerinfo_final project` c
        ON t.ID_client = c.Id_client
),

quarterly AS (
    SELECT
        age_group,
        CONCAT(YEAR(date_new), '-Q', QUARTER(date_new)) AS quarter,
        SUM(Sum_payment) AS total_sum,
        COUNT(*) AS total_ops,
        AVG(Sum_payment) AS avg_payment,
        COUNT(*) / COUNT(DISTINCT ID_client) AS avg_ops_per_client
    FROM base
    GROUP BY age_group, quarter
),

year_totals AS (
    SELECT
        CONCAT(YEAR(date_new), '-Q', QUARTER(date_new)) AS quarter,
        SUM(Sum_payment) AS sum_q,
        COUNT(*) AS ops_q
    FROM base
    GROUP BY quarter
)

SELECT
    q.age_group,
    q.quarter,

    -- Сумма и количество операций за весь период
    q.total_sum,
    q.total_ops,

    -- Средние показатели поквартально
    q.avg_payment,
    q.avg_ops_per_client,

    -- % доля возрастной группы в квартале
    q.total_sum / yt.sum_q AS share_sum_quarter,
    q.total_ops / yt.ops_q AS share_ops_quarter

FROM quarterly q
JOIN year_totals yt USING (quarter)
ORDER BY q.quarter, q.age_group;
