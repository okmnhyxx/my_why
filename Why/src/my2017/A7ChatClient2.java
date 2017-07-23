package my2017;

import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.EOFException;
import java.io.IOException;
import java.net.Socket;
import java.net.SocketException;
import java.net.UnknownHostException;

/**
 * Created by emi on 2017/7/21.
 */
public class A7ChatClient2 extends Frame{

    Socket s = null;
    DataOutputStream dos = null;
    DataInputStream dis = null;
    private boolean bConnected = false;

    TextField tfTxt = new TextField();
    TextArea taContent = new TextArea();

    Thread tRecv = new Thread(new RecvThread());

    public static void main(String[] args) {
        new A7ChatClient2().launchFrame(8888);
    }

    public void launchFrame(int port) {
        setLocation(400, 400);
        this.setSize(300, 300);
        add(tfTxt, BorderLayout.SOUTH);
        add(taContent, BorderLayout.NORTH);
        pack();
        this.addWindowListener(new WindowAdapter() {

            @Override
            public void windowClosing(WindowEvent arg0) {
                disconnect();
                System.exit(0);
            }

        });
        tfTxt.addActionListener(new TFListener());
        setVisible(true);
        connect(port);

        tRecv.start();
    }

    public void connect(int port) {
        try {
            s = new Socket("127.0.0.1", port);
            dos = new DataOutputStream(s.getOutputStream());
            dis = new DataInputStream(s.getInputStream());
            System.out.println("~~~~~~~~2连接成功~~~~~~~~!");
            bConnected = true;
        } catch (UnknownHostException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }

    }

    public void disconnect() {
        try {
            dos.close();
            dis.close();
            s.close();
        } catch (IOException e) {
            e.printStackTrace();
        }

    }

    private class TFListener implements ActionListener {

        public void actionPerformed(ActionEvent e) {
            String str = tfTxt.getText().trim();
            tfTxt.setText("");

            try {
                dos.writeUTF(str);
                dos.flush();
            } catch (IOException e1) {
                e1.printStackTrace();
            }

        }

    }

    private class RecvThread implements Runnable {

        public void run() {
            try {
                while (bConnected) {
                    String str = dis.readUTF();
                    taContent.setText(taContent.getText() + str + '\n');
                }
            } catch (SocketException e) {
                System.out.println("退出了，bye!");
            } catch (EOFException e) {
                System.out.println("退出了，bye!");
            } catch (IOException e) {
                e.printStackTrace();
            }

        }

    }
}
