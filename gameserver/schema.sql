CREATE TABLE profiles (
    url         varchar(512) PRIMARY KEY,
    region      varchar(3) NOT NULL,
    name        varchar(128) NOT NULL,
    league      varchar(2) NOT NULL
);
