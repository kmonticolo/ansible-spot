use master
GO
declare @sql nvarchar(512)
select @sql = 'Create Database mpeg ON PRIMARY
( NAME = mpeg_data,
FILENAME = ''d:\sql\data\mpeg_data.mdf'',
SIZE = 600MB,
FILEGROWTH = 10% )
LOG ON
( NAME = mpeg_log,
FILENAME = ''C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\DATA\mpeg_log.ldf'',
SIZE = 300MB,
MAXSIZE = 10GB,
FILEGROWTH = 10%)
COLLATE Latin1_General_BIN'
exec sp_executesql @sql
GO

alter database mpeg set RECOVERY Simple
alter database mpeg set AUTO_SHRINK ON
