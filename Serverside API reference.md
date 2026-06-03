Serverside API reference
The itch.io server-side API lets you query information about your games and account by making HTTP requests to the API hosted at api.itch.io.

Looking for the older itch.io/api/1/KEY/... endpoints? See the legacy serverside API reference.

Table of contents
Authentication
API keys
JWT tokens
Scopes
Passing parameters
Response format
Reference
https://api.itch.io/credentials/info
https://api.itch.io/profile
https://api.itch.io/profile/games
https://api.itch.io/games/GAME_ID/download_keys
https://api.itch.io/games/GAME_ID/purchases
https://api.itch.io/wharf/latest
Authentication
All API endpoints require authentication. Credentials are passed in the HTTP Authorization header as a bearer token:

GET https://api.itch.io/profile
Authorization: Bearer YOUR_API_KEY
There are two types of credentials you can use:

API keys are long-lasting credentials that can be revoked by users
JWT tokens are short-lived, expiring credentials
Both are passed using the same Authorization: Bearer header — the API distinguishes between them automatically.

API keys
You can generate API keys for your own account from the API keys page. (You'll need an itch.io account if you don’t already have one.)

If you want to make requests on behalf of other itch.io users, you can register an OAuth application and have them grant permissions to your app.

GET https://api.itch.io/profile
Authorization: Bearer YOUR_API_KEY
JWT tokens
JWT tokens can be passed to a game when it specifies a list of requested API scopes. Read the app manifest documentation for more information.

GET https://api.itch.io/profile
Authorization: Bearer YOUR_JWT_TOKEN
Scopes
Credentials (whether they're API keys or JWT tokens) usually have a limited scope, which means they'll give access to some endpoints but not others.

In the API reference below, endpoints are listed with: HTTP method (in blue), scope (in green), and template URL.

Having access to a scope gives access to all its subscopes. For example, profile gives access to profile:me, but game:view:purchases does not give access to game:view.

API keys that you generate from your user settings are unscoped — they have access to all endpoints.

Passing parameters
GET requests that take parameters should insert them in the query string.

POST requests can either take parameters as a form-encoded body, or in the query string.

Response format
API responses are JSON-encoded, and use snake_case.

Errors are signaled by the presence of an errors field (an array of strings) in the response body.

Dates are returned in RFC 3339 format (UTC), for example: 2017-10-19T13:35:06Z

Reference
https://api.itch.io/credentials/info
Returns information on the set of credentials used to make this API request. The response includes the credential type ("key" for API keys, "jwt" for JWT tokens), the list of scopes the credentials give access to, and (for JWT tokens) the expiration date.

Takes no parameters.

Sample response for JWT token:

{
  "type": "jwt",
  "scopes": [ "profile:me" ],
  "expires_at": "2017-10-19T13:35:06Z"
}
Sample response for API key:

{
  "type": "key",
  "scopes": [ "profile:me", "profile:games" ]
}
profile:me
https://api.itch.io/profile
Fetches public profile data for the user to which the API key belongs.

Takes no parameters.

Sample response:

{
  "user": {
    "username": "fasterthanlime",
    "gamer": true,
    "display_name": "Amos",
    "cover_url": "https://img.itch.zone/aW1hZ2UyL3VzZXIvMjk3ODkvNjkwOTAxLnBuZw==/100x100%23/JkrN%2Bv.png",
    "url": "https://fasterthanlime.itch.io",
    "press_user": true,
    "developer": true,
    "id": 29789
  }
}
profile:games
https://api.itch.io/profile/games
Fetches data about all the games you've uploaded or have edit access to.

Takes no additional parameters.

Sample response:

{
   "games":[
      {
         "cover_url":"http:\/\/img.itch.io\/aW1hZ2UvMy8xODM3LnBuZw==\/315x250%23\/y2uYQI.png",
         "created_at":"2013-03-03T23:02:14Z",
         "downloads_count":109,
         "id":3,
         "min_price":0,
         "traits":["p_windows","p_linux","p_osx"],
         "classification":"game",
         "published":true,
         "published_at":"2013-03-03T23:02:14Z",
         "purchases_count":4,
         "short_text":"Humans have been colonizing planets. It's time to stop them!",
         "title":"X-Moon",
         "type":"default",
         "url":"http:\/\/leafo.itch.io\/x-moon",
         "views_count":2682,
         "earnings":[
            {
               "currency":"USD",
               "amount_formatted":"$50.47",
               "amount":5047
            }
         ]
      }
   ]
}
game:view:purchases
https://api.itch.io/games/GAME_ID/download_keys
Checks if a download key exists for game and returns it.

GAME_ID can be retrieved from the /profile/games API call above.

Requires either of the following parameters:

download_key: The download key to look up,
or user_id: The user identifier to look up download keys for.
or email: The e-mail to look up download keys for.
You can use this API call to verify that someone has a valid download key to download the game.

The download key can be extracted from a buyer’s download URL. For example:

http://leafo.itch.io/x-moon/download/YWKse5jeAeuZ8w3a5qO2b2PId1sChw2B9b637w6z

The download key would be YWKse5jeAeuZ8w3a5qO2b2PId1sChw2B9b637w6z.

Passing user_id instead is useful in scenarios where you have authenticated a user via an app manifest. That makes it impossible for users to spoof their user_id.

When passing email, you are responsible for verifying the user’s email address first, otherwise they could attempt to guess an email they don’t own in order to fake ownership.

Sample output:

{
  "download_key": {
    "id":124,
    "created_at":"2014-02-28T00:25:09Z",
    "downloads":74,
    "key":"YWKse5jeAeuZ8w3a5qO2b2PId1sChw2B9b637w6z",
    "game_id":3,
    "owner":{
      "display_name": "Amos",
      "gamer": true,
      "username": "fasterthanlime",
      "id": 1994,
      "url": "https://fasterthanlime.itch.io",
      "press_user": true,
      "developer": true,
      "cover_url":
      "https://img.itch.io/aW1hZ2UyL3VzZXIvMjk3ODkvMTk4MjkwLnBuZw==/100x100%23/qg3l0J.png"
    },
  }
}
If download_key is invalid, revoked, or for another game, returns:

{
  "errors": ["invalid download key"]
}
If email or user_id hasn’t purchased or claimed the game, returns:

{
  "errors": ["no download key found"]
}
game:view:purchases
https://api.itch.io/games/GAME_ID/purchases
Returns the purchases an email address has created for a given game. Only successfully completed purchases are shown.

GAME_ID can be retrieved from the /profile/games API call above.

Requires either of the following parameters:

email: The email address to look up purchases for,
or user_id: The user identifier to look up purchases for.
The call is aware of verified email addresses associated with the one you provide. Meaning if someone has the email person@example.com and has linked person2@example.com. You can request with either email address to get their purchase regardless of which email address it originated from.

You can use this API call to verify that someone has bought your game on itch.io on your own server. You are responsible for verifying their email address first, otherwise they could attempt to guess an email they don’t own in order to fake ownership.

Claimed keys do not have purchases associated with them, and so this endpoint will return an empty purchases object. To look up both claimed keys and purchased keys, use the /download_keys endpoint.

Sample output:

{
   "purchases":[
      {
         "donation":false,
         "id":11561,
         "email":"leaf@example.com",
         "created_at":"2014-02-28T00:25:09Z",
         "source":"amazon",
         "currency":"USD",
         "price":"$1.00",
         "sale_rate":0,
         "quantity":1,
         "status":"complete",
         "purchase_type":"game",
         "game_id":3
      }
   ]
}
The donation field is true for any purchase that doesn’t have a download key associated with it, currently this only applies to web games.

purchase_type is one of game, bundle, or sub_product. When the purchase is for a bundle that includes the game being queried, game_id is returned as an array of all game IDs included in that bundle.

https://api.itch.io/wharf/latest
Returns the latest user-version for a given channel. Useful for notifying players from within a game when a new version of a build is available, without having to bundle the itch app.

This endpoint does not require authentication.

Requires the following parameter:

channel_name: the name of the channel to query (for example win32-beta, osx-final)
Plus either of:

game_id: numeric identifier of the game (found on the Edit game page),
or target: user/game slug, just like the butler push command.
Sample response:

{
  "latest": "1.2.3"
}
If the latest build does not have a user-version (i.e. the developer didn’t pass --userversion or --userversion-file when pushing), the latest field will be omitted from the response.

Example requests:

GET https://api.itch.io/wharf/latest?target=user/game&channel_name=win32-beta
GET https://api.itch.io/wharf/latest?game_id=123&channel_name=osx-final
If the game’s visibility level is set to Private, this endpoint returns the error invalid game, to avoid potentially leaking information about unreleased games.