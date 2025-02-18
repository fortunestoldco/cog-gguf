from typing import List, Optional
from cog import BasePredictor, Input
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

CACHE_DIR = 'weights'

# Model details with the correct gguf file for loading the model
MODEL_ID = "TheBloke/GOAT-70B-Storytelling-GGUF"
FILENAME = "goat-70b-storytelling.Q5_K_M.gguf"

class Predictor(BasePredictor):
    def setup(self):
        # Use GPU if available, otherwise fall back to CPU
        self.device = 'cuda' if torch.cuda.is_available() else 'cpu'
        
        # Load the model and tokenizer with GGUF file
        self.tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, gguf_file=FILENAME)
        self.model = AutoModelForCausalLM.from_pretrained(MODEL_ID, gguf_file=FILENAME)
        
        # Move model to the appropriate device
        self.model.to(self.device)

    def predict(
        self,
        prompt: str = Input(description="Text prompt to send to the model."),
        n: int = Input(description="Number of output sequences to generate", default=1, ge=1, le=5),
        max_length: int = Input(
            description="Maximum number of tokens to generate. A word is generally 2-3 tokens",
            ge=1,
            default=50
        ),
        temperature: float = Input(
            description="Adjusts randomness of outputs, greater than 1 is random and 0 is deterministic, 0.75 is a good starting value.",
            ge=0.01,
            le=5,
            default=0.75,
        ),
        top_p: float = Input(
            description="When decoding text, samples from the top p percentage of most likely tokens; lower to ignore less likely tokens",
            ge=0.01,
            le=1.0,
            default=1.0
        ),
        repetition_penalty: float = Input(
            description="Penalty for repeated words in generated text; 1 is no penalty, values greater than 1 discourage repetition, less than 1 encourage it.",
            ge=0.01,
            le=5,
            default=1
        )
    ) -> List[str]:
        # Tokenize the input prompt
        input_ids = self.tokenizer(prompt, return_tensors="pt").input_ids.to(self.device)
        
        # Generate model outputs
        outputs = self.model.generate(
            input_ids,
            num_return_sequences=n,
            max_length=max_length,
            do_sample=True,
            temperature=temperature,
            top_p=top_p,
            repetition_penalty=repetition_penalty
        )
        
        # Decode the output and return
        decoded_output = self.tokenizer.batch_decode(outputs, skip_special_tokens=True)
        return decoded_output
