import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense
from tensorflow.keras.utils import to_categorical

# load csv landmark data into pandas dataframe df
df = pd.read_csv('C:/Users/plaza/PycharmProjects/fypproject/landmarks_final.csv')
X = df.iloc[:, :-1].values  # X = feature columns 0-63
y = df['gesture_label'].values  # Y = final column (gesture label)

# encode the label
label_encoder = LabelEncoder()
y_encoded = label_encoder.fit_transform(y)
y_categorical = to_categorical(y_encoded)

# split data for train and test 80/20
X_train, X_test, y_train, y_test = train_test_split(X, y_categorical, test_size=0.2, random_state=42)

# define model
model = Sequential([
    Dense(64, activation='relu', input_shape=(63,)),
    Dense(64, activation='relu'),
    Dense(len(label_encoder.classes_), activation='softmax')
])

# compile model with adam optimizer, sparse categorical crossentropy, and measure accuracy metric
model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

#  training - 10 epochs
model.fit(X_train, y_train, epochs=10, validation_split=0.1)

# evaluate model performance
loss, accuracy = model.evaluate(X_test, y_test)
print(f'Test loss: {loss}, Test accuracy: {accuracy}')

model.save('conductify_nn.h5')

# insert new landmark data for prediction test
new_landmarks = [0.41761553287506104,0.7011496424674988,-2.3314935049256746e-07,0.4915030896663666,0.6781885623931885,-0.06324149668216705,0.5633525848388672,0.604102373123169,-0.09157919883728027,0.5672330856323242,0.5156115889549255,-0.11516806483268738,0.5207087397575378,0.45859387516975403,-0.13581909239292145,0.5760734677314758,0.47096601128578186,-0.0383797213435173,0.6047306656837463,0.37487128376960754,-0.06295651942491531,0.6111264824867249,0.31842172145843506,-0.07124137878417969,0.6190457940101624,0.26980194449424744,-0.07466758787631989,0.5105882883071899,0.4561709761619568,-0.03125828132033348,0.5280072689056396,0.37403953075408936,-0.08931057155132294,0.5197720527648926,0.45264291763305664,-0.10676497220993042,0.5214225649833679,0.5140122771263123,-0.0980803519487381,0.44827550649642944,0.45805442333221436,-0.030434902757406235,0.45702069997787476,0.40114864706993103,-0.0897921547293663,0.47470226883888245,0.48468253016471863,-0.09284082055091858,0.49030452966690063,0.5498707294464111,-0.07401832193136215,0.3849789500236511,0.4693761467933655,-0.03459358960390091,0.37600943446159363,0.38689789175987244,-0.06207417696714401,0.37248140573501587,0.3399481177330017,-0.0635971873998642,0.3769664168357849,0.2944786846637726,-0.0575871542096138]
new_landmarks = np.array(new_landmarks).reshape(1, -1)

# make a prediction using the new landmark data
predicted = model.predict(new_landmarks)
predicted_label_index = np.argmax(predicted)
predicted_label = label_encoder.inverse_transform([predicted_label_index])

print("Predicted gesture:", predicted_label)
