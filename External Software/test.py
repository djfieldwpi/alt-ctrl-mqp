import time

while True:
    with open("C:\\Users\\field\\Desktop\\College Documents\\MQP\\alt-ctrl-mqp\\signal.txt", 'r') as f:
        if (f.readline().strip() == "GO"):
            f.close()
            with open("C:\\Users\\field\\Desktop\\College Documents\\MQP\\alt-ctrl-mqp\\signal.txt", 'w') as f:
                f.write("DONE")
                f.close()

    time.sleep(1)
