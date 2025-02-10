import os
import base64
from groq import Groq

GROQ_API_KEY = os.environ.get('GROQ_API_KEY')

# image_path = 'images/headache.jpeg'

def encode_image(image_file):   
    # image_file=open(image_path, "rb")
    return base64.b64encode(image_file.read()).decode('utf-8')

query = "Is there any problem here?"
model = "llama-3.2-90b-vision-preview"

def analyze_image_with_query(query, model, image_file):
    client=Groq()   
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "text", 
                    "text": query
                },
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{encode_image(image_file)}",
                    },
                },
            ],
        }]
    chat_completion=client.chat.completions.create(
        messages=messages,
        model=model
    )

    return chat_completion.choices[0].message.content