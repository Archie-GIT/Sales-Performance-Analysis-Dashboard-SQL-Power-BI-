SELECT * FROM sales_data;

--Checking total row count
SELECT 
    COUNT(*) 
    FROM sales_data;

--Checking for null sale
SELECT 
    COUNT(*) 
    FROM sales_data
    WHERE SALES is null

---Creating tables (Customers, Products & Orders)

IF OBJECT_ID('Customers', 'U') IS NOT NULL
DROP TABLE Customers;

CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName VARCHAR(100) NOT NULL,
    ContactFirstName VARCHAR(50),
    ContactLastName VARCHAR(50),
    Phone VARCHAR(30),
    AddressLine1 VARCHAR(150),
    AddressLine2 VARCHAR(150),
    City VARCHAR(50),
    State VARCHAR(50),
    PostalCode VARCHAR(20),
    Country VARCHAR(50),
    Territory VARCHAR(50)
);


IF OBJECT_ID('Products', 'U') IS NOT NULL
DROP TABLE Products;

CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductCode VARCHAR(50) NOT NULL UNIQUE,
    ProductLine VARCHAR(100),
    MSRP DECIMAL(10,2)
);

IF OBJECT_ID('Orders', 'U') IS NOT NULL
DROP TABLE Orders;

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    OrderNumber INT NOT NULL,
    OrderDate DATE,
    Status VARCHAR(50),
    DealSize VARCHAR(20),

    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,

    QuantityOrdered INT,
    PriceEach DECIMAL(10,2),
    Sales DECIMAL(12,2),

    CONSTRAINT FK_Orders_Customers 
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),

    CONSTRAINT FK_Orders_Products
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);


--Inserting the blank tables with data

INSERT INTO Customers(
    CustomerName,
    ContactFirstName,
    ContactLastName,
    Phone,
    AddressLine1,
    AddressLine2,
    City,
    State,
    PostalCode,
    Country,
    Territory
)
SELECT DISTINCT 
    CustomerName,
    ContactFirstName,
    ContactLastName,
    Phone,
    AddressLine1,
    AddressLine2,
    City,
    State,
    PostalCode,
    Country,
    Territory
FROM sales_data;


INSERT INTO Products (
    ProductCode,
    ProductLine,
    MSRP
)
SELECT DISTINCT 
    ProductCode,
    ProductLine,
    MSRP
FROM sales_data


INSERT INTO Orders (
    OrderNumber,
    OrderDate,
    Status,
    CustomerID,
    ProductID,
    QuantityOrdered,
    PriceEach,
    Sales,
    DealSize
)
SELECT 
    s.OrderNumber,
    s.OrderDate,
    s.Status,
    c.CustomerID,
    p.ProductID,
    s.QuantityOrdered,
    s.PriceEach,
    s.Sales,
    s.DEALSIZE
FROM sales_data s
JOIN Customers c 
    ON s.CustomerName = c.CustomerName
JOIN Products p 
    ON s.ProductCode = p.ProductCode;

--Changes in Customer Table
--Renaming Customer name as Business entties
EXEC sp_rename 'Customers.CustomerName','BusinessEntity','Column'

--Join Colums first and last name

ALTER TABLE Customers
ADD CustomerName VARCHAR(255);

UPDATE Customers
SET CustomerName = CONCAT(ContactFirstName, ' ', ContactLastName);

ALTER TABLE Customers
DROP COLUMN ContactFirstName, ContactLastName;

--For NULL state & postal code
UPDATE Customers
SET State = 'Unknown'
WHERE State IS NULL;

UPDATE Customers
SET PostalCode = 'Unknown'
WHERE PostalCode IS NULL;


/*Creatingindexes
Clustered: PK, Onepertable, Incremental(date or id), physically sort table.
Non-clus: multiplepertable, no physical sorting, fk or frequently use search columns*/

CREATE NONCLUSTERED INDEX IX_Customers_BusinessEntity
ON Customers(BusinessEntity);

CREATE INDEX IX_Products_ProductCode
ON Products(ProductCode);

CREATE INDEX IX_Orders_ProductID
ON Orders (ProductID);

CREATE INDEX IX_Orders_CustomerID
ON Orders (CustomerID);

CREATE INDEX IX_Orders_OrderDate
ON Orders(OrderDate);

EXEC sp_helpindex 'Orders';


--Queries b/s related

--Total revenue * orders
SELECT * FROM sales_data;
SELECT * FROM Orders;
SELECT * FROM Customers;
SELECT * FROM Products;


--Total revenue and orders

SELECT SUM(Sales) as Revenue
FROM Orders

SELECT COUNT(DISTINCT OrderNumber) as TotalOrders
FROM Orders

--Revenue country wise
SELECT 
    c.Country,
    SUM(o.Sales) AS Revenue
FROM Orders o
LEFT JOIN Customers c 
ON c.CustomerID = o.CustomerID
GROUP BY Country
ORDER BY Revenue DESC
 
--Revenue based on productline

SELECT
    p.ProductLine,
    SUM(o.Sales) as Revenue
FROM  Orders o
LEFT JOIN Products p
ON p.ProductID =o.ProductID
GROUP BY p.ProductLine
ORDER BY Revenue DESC

-- Highest revenue customer 
SELECT 
    TOP 5 
    c.BusinessEntity,
    SUM(o.Sales) as Revenue
FROM Orders o
LEFT JOIN Customers c 
ON c.CustomerID = o.CustomerID
GROUP BY c.BusinessEntity
ORDER BY Revenue DESC

-- Monthly trend of revenue

SELECT
    YEAR(OrderDate) AS Year,
    MONTH(OrderDate) AS Month,
    DATENAME(MONTH, OrderDate) AS OrderMonth,
    SUM(Sales) as Revenue
FROM Orders
GROUP BY YEAR(OrderDate), MONTH(OrderDate), DATENAME(MONTH, OrderDate)
ORDER BY Year, OrderMonth

--Average order value
SELECT
SUM(Sales)/COUNT(DISTINCT OrderNumber) AOV
FROM Orders


--Revenue by size of deal
SELECT  
    DealSize,
    SUM(Sales) as Revenue
FROM Orders
GROUP BY DealSize
ORDER BY Revenue DESC

--Profit calculation
SELECT
    p.ProductCode,
    (o.Sales  - o.QuantityOrdered * p.MSRP) AS Profit
FROM Orders o
LEFT JOIN Products p
ON o.ProductID = p.ProductID

---Customer with >15 orders
SELECT
  c.BusinessEntity, 
  COUNT( o.OrderNumber) AS TotalOrders
FROM Orders o
LEFT JOIN Customers c 
ON c.CustomerID = o.CustomerID
GROUP BY  c.BusinessEntity, o.OrderNumber
HAVING COUNT( o.OrderNumber) >= 15

--Top 3 Products per Product Line (Using Window Function)
;WITH CTE_rnk AS(
SELECT 
p.ProductLine,p.ProductCode,SUM(o.Sales) AS Revenue,
RANK() OVER(PARTITION BY ProductLine ORDER BY SUM(ISNULL(o.Sales,0)) DESC)AS RNK

FROM Products p
LEFT JOIN Orders o
ON o.ProductID = p.ProductID
GROUP BY p.ProductLine,p.ProductCode
)
SELECT *
FROM CTE_rnk
WHERE RNK<=3;

--YOY Growth 
WITH CTE AS(
SELECT
    SUM(Sales) AS Revenue,
    Year(OrderDate) AS OrderYear
FROM Orders
GROUP BY Year(OrderDate)
)
SELECT 
OrderYear,
Revenue,
LAG(Revenue) OVER (ORDER BY OrderYear) AS PreviousYearRevenue,
CASE WHEN LAG(Revenue) OVER (ORDER BY OrderYear) IS NULL THEN NULL ELSE
(Revenue - LAG(Revenue) OVER (ORDER BY OrderYear))*100.0/LAG(Revenue) OVER (ORDER BY OrderYear) END AS YOY
FROM CTE

--Running total of sales
SELECT
    OrderDate,
    Sales,
    SUM(Sales) OVER(ORDER BY OrderDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Running_total
FROM Orders;

--Most profitable territory
WITH CTE AS(
SELECT 
    c.Territory,
    SUM(o.Sales) AS Revenue
FROM Orders o
LEFT JOIN Customers c
ON c.CustomerID = o.CustomerID
GROUP BY Territory
)
SELECT TOP 1 *
FROM CTE
ORDER BY Revenue DESC

--Identify High-Value Customers (Above Average Revenue)
WITH CTE AS(
SELECT
    c.BusinessEntity,
    SUM(Sales) AS Revenue
FROM Orders o
LEFT JOIN Customers c
ON c.CustomerID = o.CustomerID
GROUP BY c.BusinessEntity
) 
SELECT
   *
FROM CTE
WHERE Revenue > (SELECT AVG(Revenue) FROM CTE)

--Contribution % of Each Product
SELECT 
    p.ProductCode,
    SUM(o.Sales) AS Revenue,
    SUM(o.Sales) *100.0 /SUM(SUM(o.Sales)) OVER() AS Contribution
    FROM Orders o
LEFT JOIN Products p
ON p.ProductID = o.ProductID
GROUP BY p.ProductCode


--Customer lifetimevalue
SELECT
    c.BusinessEntity,
    COUNT(c.CustomerID) AS TotalOrders,
    SUM(o.Sales) AS CustomerLV,
    MIN(o.OrderDate) as Min_Date,
    MAX(o.OrderDate) AS Max_Date
FROM Customers c
LEFT JOIN Orders o 
ON c.CustomerID = o.CustomerID
GROUP BY c.CustomerID, c.BusinessEntity
ORDER BY CustomerLV DESC

--Rolling 12-months revenue
SELECT
    YEAR(OrderDate) AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    SUM(o.Sales) AS Revenue,
    SUM(SUM(o.Sales))OVER (ORDER BY YEAR(OrderDate) ,MONTH(OrderDate)
    ROWS BETWEEN 11 PRECEDING AND  CURRENT ROW) AS Rolling_rev
FROM Customers c
LEFT JOIN Orders o 
ON c.CustomerID = o.CustomerID
GROUP BY YEAR(OrderDate) ,MONTH(OrderDate)
ORDER BY YEAR(OrderDate) ,MONTH(OrderDate)

--Top product per territory
WITH CTE AS (
SELECT
    c.Territory, 
    p.ProductCode,
    SUM(o.Sales) AS Revenue,
    RANK() OVER (PARTITION BY c.Territory ORDER BY SUM(o.Sales)) as rnk
FROM Orders o
LEFT JOIN Customers c
ON c.CustomerID = o.CustomerID
LEFT JOIN Products p
ON p.ProductID = o.ProductID
GROUP BY c.Territory, p.ProductCode
)
SELECT Territory, ProductCode, Revenue
FROM CTE
WHERE rnk = 1