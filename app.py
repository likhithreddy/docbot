from flask import Flask, request, jsonify
from flask_cors import CORS
from doctor_brain import analyze_image_with_query

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

@app.route('/analyze', methods=['POST'])
def analyze():
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided."}), 400
    
    image_file = request.files['image']
    query = request.form.get('query', '')
    
    if not query:
        return jsonify({"error": "No query provided."}), 400

    try:
        query = "Is there any problem here?"
        model = "llama-3.2-90b-vision-preview"
        result = analyze_image_with_query(query, model, image_file)
        return jsonify({"result": result})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Run the Flask app on port 5000 and make it accessible externally.
    app.run(debug=True, host="0.0.0.0", port=5000)
