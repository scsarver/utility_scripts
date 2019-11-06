import java.awt.AWTException;
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.PointerInfo;
import java.awt.Point;
import java.util.Random;

public final class MouseRobot
{
    public static void main(String[] args) throws AWTException {
      Robot bot = new Robot();

      PointerInfo pointer = MouseInfo.getPointerInfo();
      Point point = pointer.getLocation();

      Random rn = new Random();
      int randomNum =  rn.nextInt(10) + 1;

      bot.setAutoDelay(5);
      bot.setAutoWaitForIdle(true);
      bot.mouseMove(0, 0);
      bot.delay(500);
      bot.mouseMove( (int) point.getX()+randomNum, (int) point.getY()+randomNum);
      bot.delay(500);
      bot.mouseMove((int)point.getX(), (int)point.getY());
      System.exit(0);
    }
}
