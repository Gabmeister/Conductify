import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense
from tensorflow.keras.utils import to_categorical
from sklearn.metrics import f1_score, precision_score, recall_score, accuracy_score

# load CSV landmark data into pandas dataframe df
df = pd.read_csv('C:/Users/plaza/PycharmProjects/fypproject/landmarks_final.csv')
X = df.iloc[:, :-1].values  # X = feature columns 0-63
y = df['gesture_label'].values  # Y = final column (gesture label)

# encode label
label_encoder = LabelEncoder()
y_encoded = label_encoder.fit_transform(y)
y_categorical = to_categorical(y_encoded)

# split data for train and test 80/20
X_train, X_test, y_train, y_test = train_test_split(X, y_categorical, test_size=0.2, random_state=42)

# model definition
model = Sequential([
    Dense(64, activation='relu', input_shape=(63,)),
    Dense(64, activation='relu'),
    Dense(len(label_encoder.classes_), activation='softmax')
])

# model compilation
model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

# 10 epoch training
model.fit(X_train, y_train, epochs=10, validation_split=0.1)

loss, accuracy = model.evaluate(X_test, y_test)
print(f'Test loss: {loss}, Test accuracy: {accuracy}')

y_pred_probs = model.predict(X_test)
y_pred = np.argmax(y_pred_probs, axis=1)
y_true = np.argmax(y_test, axis=1)

# calculate precision, recall, F1 score and accuracy
precision = precision_score(y_true, y_pred, average='weighted')
print(f"Precision: {precision}")
recall = recall_score(y_true, y_pred, average='weighted')
print(f"Recall: {recall}")
f1 = f1_score(y_true, y_pred, average='weighted')
print(f"F1 Score: {f1}")
accuracy = accuracy_score(y_true, y_pred)  
print(f"Accuracy: {accuracy}")


