# CouchDB / Sinatra / REST / API

Some months ago I was involved in configuring an API to use with CouchDB.
In the process of this, I created a test application using Sinatra to utilize the various CouchDB REST calls.
This is that application.

Later I created a MUCH more sophisticated set of sub-apps in Padrino to utilize the lessons learned.

It is not great.
It is not well written.
It is not documented.
It has no tests.
But it works.

It was written in one day to get the process of using `rest-client` to operate against a test CouchDB database.
That is all.

I make no apologies for the code.

It works.
That is all.

To use it:

## Install CouchDB someplace.

I have it on an external server as shown in the `config/couchdb.yml` file.

## Clone the repo.

Goes without saying...

## Change the `config/couchdb.yml` file

Change to suit.

## Fire it up

```
rackup -s thin -o 0.0.0.0 -p 9292 -E development config.ru
```

Then open a browser to `http://0.0.0.0:9292/index.html` and start playing.

## Honestly

I would love to here from cloners who would like enhancements as I'm always ready to learn.
If you see a problem, or want to have me change something, tell me.

## Me

Ms Kimberley Scott.
Senior Software Engineer

Do you need a highly experienced technologist, toolmaker, solution architect, problem solver, trouble shooter, firefighter and innovator?
The contact me via my LinkedIn page: http://au.linkedin.com/pub/kim-scott/4/736/830/

Kimbo.
