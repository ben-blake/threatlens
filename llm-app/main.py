import os
import flask
import vertexai
from vertexai.generative_models import GenerativeModel

# Initialize Vertex AI SDK
# These environment variables are set by the Cloud Run service definition.
project_id = os.environ.get("GCP_PROJECT")
location = os.environ.get("GCP_REGION")

if not project_id or not location:
    raise EnvironmentError("GCP_PROJECT and GCP_REGION environment variables must be set.")

vertexai.init(project=project_id, location=location)

# Load the Gemini 2.0 Flash-Lite model with a specific version
model = GenerativeModel("gemini-2.0-flash-lite-001")

# Initialize the Flask application
app = flask.Flask(__name__)

@app.route("/", methods=["POST"])
def inference():
    """
    Handles inference requests. Expects a JSON payload with a "log_entry" key.
    e.g., curl -X POST -H "Content-Type: application/json" -d '{"log_entry": "sshd[1234]: Failed password for invalid user admin from 123.45.67.89 port 22 ssh2"}' <your-cloud-run-url>
    """
    if not flask.request.is_json:
        return flask.jsonify({"error": "Request must be JSON"}), 400

    data = flask.request.get_json()
    log_entry = data.get("log_entry")

    if not log_entry:
        return flask.jsonify({"error": "Missing 'log_entry' in request body"}), 400

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
        return flask.jsonify({"analysis": generated_text})

    except Exception as e:
        print(f"Error during model generation: {e}")
        return flask.jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    # The PORT environment variable is set automatically by Cloud Run.
    # Default to 8080 for local development.
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080))) 