import time

while True:
    with open("C:\\Users\\field\\Desktop\\College Documents\\MQP\\alt-ctrl-mqp\\signal.txt", 'r') as f:
        if (f.readline().strip() == "GO"):
            f.close()
            with open("C:\\Users\\field\\Desktop\\College Documents\\MQP\\alt-ctrl-mqp\\signal.txt", 'w') as f:
                vertices = [(0, 0), (200, 0), (200, 200), (0, 200)]
                vertices_str = '\n'.join([f"{x} {y}" for x, y in vertices])
                
                f.write("DONE\n" + vertices_str)
                print("DONE\n" + vertices_str)
                f.close()

    time.sleep(1)
