use dkhpdb;
DELIMITER //
CREATE TRIGGER decreaseDaDK
    AFTER DELETE ON registration
    FOR EACH ROW
BEGIN
    UPDATE course SET registered_number=registered_number-1
    WHERE id=OLD.course_id;
END //

CREATE TRIGGER increaseDaDK
    AFTER INSERT ON registration
    FOR EACH ROW
BEGIN
    UPDATE course SET registered_number=registered_number+1
    WHERE id=NEW.course_id;
END //
DELIMITER;