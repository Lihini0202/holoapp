import redis

try:
    # Connect to localhost on the default Redis port 6379
    r = redis.Redis(host='localhost', port=6379, db=0)
    
    # Try to ping the server
    response = r.ping()
    
    if response:
        print("✅ Success! Connected to Redis.")
    else:
        print("❌ Connected, but no response.")
        
except Exception as e:
    print(f"❌ Error: Could not connect to Redis. Make sure Docker is running.\nDetails: {e}")