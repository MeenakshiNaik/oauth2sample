# README

This repository is made just for answering the comment on stackoverflow
https://stackoverflow.com/questions/50523052/googleapisauthorizationerror-unauthorized?noredirect=1#comment88297966_50523052


The main issue is when I'm signing in gmail account using oauth2 it's working for 1st time and also fetching emails properly for 1st time. Access and Refresh token is also valid.

I'm checking from below link id access token is valid or not:
https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=ya29.GlvNBZFiY_doMFfbrl5ibqs04AS_hd8NwutfzQcB2WWALQYPO7F913UnuV1kHwJhdqRPKlgBP-ehoY6bqQl2Gvqs3vbQGyl9Zw42n7njrg033Wc9YA0EttE


It shows me valid response for some time but when I check after some time or refresh same link for few times, it's already expired. It gives me:

{
  "error": "invalid_token",
  "error_description": "Invalid Value"
}


Then I'm trying to refresh access token with help of refresh token, but it says:

{
    "error": "invalid_grant",
    "error_description": "Token has been expired or revoked."
}


So basically, I'm stuck and not able to do anything with access and refresh token.



