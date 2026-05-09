FROM node:18-alpine
WORKDIR /app
RUN echo '{"name":"sandbox-app","version":"1.0.0"}' > package.json
RUN cat > server.js << 'EOF'
const http = require('http');
const port = 3000;
const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'ok',
      env_id: process.env.ENV_ID,
      env_name: process.env.ENV_NAME,
      uptime: process.uptime()
    }));
  } else {
    res.writeHead(200);
    res.end(JSON.stringify({
      message: 'Hello from sandbox!',
      env_id: process.env.ENV_ID,
      env_name: process.env.ENV_NAME
    }));
  }
});
server.listen(port, () => console.log(`Running on port ${port}`));
EOF
EXPOSE 3000
CMD ["node", "server.js"]