import { useEffect } from "react";
import { Col, Form, Modal, Row } from "react-bootstrap"

const CourseForm=({courseDTO, semesters})=>{
          const shifts=[];
          useEffect(()=>{
                if(semesters.length!=0) courseDTO["semesterId"]=semesters[0].id;
          },[])
          for(let i=1;i<=10;i++) shifts.push(i);
        const handleOnChange=(e,fieldName)=>{
                courseDTO[fieldName]=e.target.value;
        }
        return (
          <Form>
                    <Row className="mb-3">
                              <Form.Group as={Col} sm={5} controlId="courseId">
                                        <Form.Label>Mã học phần</Form.Label>
                                        <Form.Control type="text" onChange={(e)=>handleOnChange(e,"courseId")}/>
                              </Form.Group>
                              <Form.Group as={Col} sm={7} controlId="semesterId">
                                        <Form.Label>Học kì</Form.Label>
                                        <Form.Select onChange={(e)=>handleOnChange(e,"semesterId")}>
                                                  {semesters.map((se)=>(<option value={se.id}>Kì {se.semesterNum}, năm {se.year}-{se.year+1}</option>))}
                                        </Form.Select>
                              </Form.Group>
                    </Row>
                    <Row className="mb-3">
                                <Form.Group as={Col} sm={9} controlId="mainCourseId">
                                        <Form.Label>Mã học HP lý thuyết (nếu là HP thực hành)</Form.Label>
                                        <Form.Control type="text" onChange={(e)=>handleOnChange(e,"mainCourseId")}/>
                                </Form.Group>
                                 <Form.Group as={Col} controlId="totalNumber">
                                        <Form.Label>Sĩ số</Form.Label>
                                        <Form.Control type="text" onChange={(e)=>handleOnChange(e,"totalNumber")}/>
                                </Form.Group>
                    </Row>
                    <Row className="mb-3">
                              <Form.Group as={Col} controlId="language">
                                        <Form.Label>Ngôn ngữ</Form.Label>
                                        <Form.Select onChange={(e)=>handleOnChange(e,"language")}>
                                                  <option value="VN">VN</option>
                                                  <option value="EN">EN</option>
                                        </Form.Select>
                              </Form.Group>
                              <Form.Group as={Col} controlId="lectureName">
                                        <Form.Label>Tên giảng viên</Form.Label>
                                        <Form.Control type="text" onChange={(e)=>handleOnChange(e,"lectureName")}/>
                              </Form.Group>
                              <Form.Group as={Col} controlId="room">
                                        <Form.Label>Phòng học</Form.Label>
                                        <Form.Control type="text" onChange={(e)=>handleOnChange(e,"room")}/>
                              </Form.Group>
                    </Row>
                    <Row className="mb-3">
                              <Form.Group as={Col} controlId="beginDate">
                                        <Form.Label>Ngày BD</Form.Label>
                                        <Form.Control type="date" onChange={(e)=>handleOnChange(e,"beginDate")}/>
                                </Form.Group>
                                <Form.Group as={Col} controlId="endDate">
                                        <Form.Label>Ngày KT</Form.Label>
                                        <Form.Control type="date" onChange={(e)=>handleOnChange(e,"endDate")}/>
                                </Form.Group>
                    </Row>
                    <Row className="mb-3">
                                <Form.Group as={Col} controlId="dayOfWeek">
                                        <Form.Label>Ngày học</Form.Label>
                                        <Form.Select onChange={(e)=>handleOnChange(e,"dayOfWeek")}>
                                                {shifts.map((i)=>{
                                                        if(i>=2&&i<=7) return(<option value={i}>Thứ {i}</option>)
                                                })}
                                        </Form.Select>
                                </Form.Group>
                                <Form.Group as={Col} controlId="beginShift">
                                        <Form.Label>Tiết BD</Form.Label>
                                        <Form.Select onChange={(e)=>handleOnChange(e,"beginShift")}>
                                                  {shifts.map((i)=>(<option value={i}>{i}</option>))}
                                        </Form.Select>
                                </Form.Group>
                                <Form.Group as={Col} controlId="endShift">
                                        <Form.Label>Tiết KT</Form.Label>
                                        <Form.Select onChange={(e)=>handleOnChange(e,"endShift")}>
                                                  {shifts.map((i)=>(<option value={i}>{i}</option>))}
                                        </Form.Select>
                                </Form.Group>
                                <Form.Group as={Col} controlId="weekDistance">
                                        <Form.Label>Cách tuần</Form.Label>
                                        <Form.Select onChange={(e)=>handleOnChange(e,"weekDistance")}>
                                                  <option value={1}>1</option>
                                                  <option value={2}>2</option>
                                        </Form.Select>
                                </Form.Group>
                    </Row>
          </Form>
          );
}
export default CourseForm;