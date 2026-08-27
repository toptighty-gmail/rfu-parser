# Hosting the RFU Parser on AWS

This guide provides step-by-step instructions for deploying your Flask RFU Parser application to **AWS (Amazon Web Services)** for hosting and online testing.

We recommend two managed services that handle code execution, scaling, and load balancing automatically, keeping your infrastructure management to a minimum.

---

## Method 1: AWS Elastic Beanstalk (Recommended & Simplest)

AWS Elastic Beanstalk is a Platform-as-a-Service (PaaS) that runs Flask applications out of the box with zero server configuration.

### Step 1: Prepare the Files
Elastic Beanstalk requires a standard entry point (named `application.py` or configured in a WSGI file) and a list of dependencies.

1. **Create `requirements.txt`**:
   In your project directory, generate the dependencies list:
   ```powershell
   pip freeze > requirements.txt
   ```
   *(Ensure it includes `Flask`, `beautifulsoup4`, `requests`, and `rich`)*

2. **Add WSGI Configuration (`.ebextensions/`)**:
   Create a folder named `.ebextensions` and add a file named `django.config` (or `flask.config`):
   ```yaml
   option_settings:
     aws:elasticbeanstalk:container:python:
       WSGIPath: app:app
     aws:elasticbeanstalk:application:environment:
       PYTHONPATH: "/var/app/current"
   ```

3. **Zip the Code**:
   Select all files in the `rfu-parser` directory (excluding virtual environments like `.venv` or `__pycache__`) and compress them into a `.zip` file (e.g., `rfu-parser-v1.zip`).

### Step 2: Deploy via AWS Console
1. Open the **AWS Elastic Beanstalk Console**.
2. Click **Create Application**.
3. Choose **Python** as the platform.
4. Under **Application code**, select **Upload your code** and upload the `.zip` file you created.
5. Click **Create Application**.
6. AWS will provision an EC2 instance, set up a load balancer, and deploy the application. It will give you a public URL (e.g., `http://rfuparser-env.eba-xxxx.us-east-1.elasticbeanstalk.com`) where you can test it online!

---

## Method 2: AWS App Runner (Modern Container-based Deployment)

AWS App Runner is a fully managed service that makes it easy to build and run containerized web applications directly from a GitHub repository or a Docker registry.

### Step 1: Create a `Dockerfile`
Create a file named `Dockerfile` (no extension) in the root of the project:
```dockerfile
# Use official lightweight Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all project code
COPY . .

# Expose Flask default port
EXPOSE 5000

# Start Flask app using gunicorn for production stability
RUN pip install gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
```

### Step 2: Deploy to App Runner
1. **GitHub Connection**: Push your code to a GitHub repository.
2. Open the **AWS App Runner Console**.
3. Click **Create Service**.
4. Select **Repository source** -> **GitHub** and connect your repository.
5. Under **Deployment settings**, choose **Automatic** (so pushing code to main redeploys the app instantly).
6. Under **Configure build**, select **Use a configuration file** or choose:
   - **Runtime**: `Python 3`
   - **Build command**: `pip install -r requirements.txt`
   - **Start command**: `gunicorn -b 0.0.0.0:5000 app:app`
   - **Port**: `5000`
7. Click **Deploy**. AWS will build the container and provide an HTTPS-secured public URL.

---

## A3 Printing & Poster Customization

When viewing the dashboard on your deployed website:
1. Search/Parse the division and team you want.
2. Click the **Print Poster (A3)** button at the top-right.
3. In the browser print dialog:
   - **Destination**: Choose your printer or "Save to PDF".
   - **Paper Size**: Select **A3**.
   - **Layout**: Select **Portrait**.
   - **Margins**: Set to **Default** or **Minimum**.
   - **Options**: Enable **"Background graphics" (very important)** to print colored cards and text highlights, and disable headers/footers for a clean poster print.
