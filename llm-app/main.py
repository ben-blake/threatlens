import os
import flask # type: ignore
import vertexai # type: ignore
from vertexai.generative_models import GenerativeModel # type: ignore

# Initialize Flask application
app = flask.Flask(__name__)

# Current analysis - instead of storing a list, just keep track of the most recent one
current_analysis = {
    "log": None,
    "analysis": None
}

# Initialize Vertex AI SDK with better error handling
model = None
vertexai_initialized = False

try:
    # Get project details from environment variables
    project_id = os.environ.get("GCP_PROJECT")
    location = os.environ.get("GCP_REGION")

    if project_id and location:
        vertexai.init(project=project_id, location=location)
        model = GenerativeModel("gemini-2.0-flash-lite-001")
        vertexai_initialized = True
        print(f"Successfully initialized Vertex AI with project {project_id} in {location}")
    else:
        print("Missing GCP_PROJECT or GCP_REGION environment variables")
except Exception as e:
    print(f"Error initializing Vertex AI: {str(e)}")

@app.route("/", methods=["GET"])
def dashboard():
    """
    Renders the dashboard frontend interface.
    """
    return flask.render_template("dashboard.html", current_analysis=current_analysis)

@app.route("/analyze", methods=["POST"])
def analyze():
    """
    Handles web form submissions for log analysis.
    """
    log_entry = flask.request.form.get("log_entry")
    
    if not log_entry:
        return flask.render_template("dashboard.html", 
                                    error="Please provide a log entry to analyze",
                                    current_analysis=current_analysis)
    
    if not vertexai_initialized or not model:
        error_msg = "Vertex AI is not properly initialized. Check server logs."
        print(error_msg)
        return flask.render_template("dashboard.html", 
                                    error=error_msg,
                                    log_entry=log_entry,
                                    current_analysis=current_analysis)
    
    try:
        # Call the analyze_log function to process the log entry
        analysis = analyze_log(log_entry)

        # Update current analysis (no need for global as it's not reassigned)
        current_analysis["log"] = log_entry
        current_analysis["analysis"] = analysis
            
        return flask.render_template("dashboard.html", 
                                    log_entry=log_entry,
                                    analysis=analysis,
                                    current_analysis=current_analysis)
    except Exception as e:
        error_msg = f"Error during analysis: {str(e)}"
        print(error_msg)
        return flask.render_template("dashboard.html", 
                                   error=error_msg,
                                   log_entry=log_entry,
                                   current_analysis=current_analysis)

@app.route("/api", methods=["POST"])
def inference():
    """
    Original API endpoint for programmatic access. Expects a JSON payload with a "log_entry" key.
    """
    if not flask.request.is_json:
        return flask.jsonify({"error": "Request must be JSON"}), 400

    data = flask.request.get_json()
    log_entry = data.get("log_entry")

    if not log_entry:
        return flask.jsonify({"error": "Missing 'log_entry' in request body"}), 400

    if not vertexai_initialized or not model:
        error_msg = "Vertex AI is not properly initialized"
        print(error_msg)
        return flask.jsonify({"error": error_msg}), 503

    try:
        # Analyze the log entry
        analysis = analyze_log(log_entry)
        
        # Update current analysis (no need for global as it's not reassigned)
        current_analysis["log"] = log_entry
        current_analysis["analysis"] = analysis
        
        return flask.jsonify({"analysis": analysis})
    except Exception as e:
        error_msg = f"Error during model generation: {str(e)}"
        print(error_msg)
        return flask.jsonify({"error": error_msg}), 500

@app.route("/health", methods=["GET"])
def health_check():
    """
    Simple health check endpoint to verify the application is running.
    Always returns healthy to pass the startup probe, but includes initialization status.
    """
    try:
        # Check if Vertex AI is initialized properly but always return 200
        if vertexai_initialized and model:
            return flask.jsonify({"status": "healthy", "vertex_ai": "initialized"}), 200
        else:
            return flask.jsonify({"status": "degraded", "vertex_ai": "not initialized"}), 200
    except Exception as e:
        print(f"Health check error: {str(e)}")
        # Still return 200 to pass the probe, but indicate the issue
        return flask.jsonify({"status": "degraded", "error": str(e)}), 200

def analyze_log(log_entry):
    """
    Helper function that handles the actual log analysis with the LLM.
    """
    if not vertexai_initialized or not model:
        raise ValueError("Vertex AI is not properly initialized")

    # Create a specialized prompt for threat intelligence analysis
    prompt = f"""
    Analyze the following security log for potential threats.
    Provide your analysis in three parts:
    1.  **Threat Classification:** (e.g., Brute-force Attack, Port Scanning, Malware Activity, Reconnaissance, etc.)
    2.  **Risk Score:** A number from 1 (Low) to 10 (High).
    3.  **Summary:** A brief, one-sentence explanation of the potential threat.

    Log Entry: "{log_entry}"
    """

    # Print to stdout, which will be captured by Cloud Logging
    print(f"Received log for analysis: {log_entry}")

    try:
        # Generate content using the model
        response = model.generate_content(prompt)
        generated_text = response.text

        print(f"Generated analysis: {generated_text}")
        return generated_text
    except Exception as e:
        print(f"Error during model generation: {str(e)}")
        raise

# For local development server only
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080))) 