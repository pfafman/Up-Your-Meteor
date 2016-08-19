
PORT=80
MONGO_URL=mongodb://127.0.0.1/<%= appName %>
ROOT_URL=http://localhost

#it is possible to override above env-vars from the user-provided values
<% for(var key in env) { %>
<%- key %>=<%- ("" + env[key]).replace(/./ig, '\\$&') %>
<% } %>
